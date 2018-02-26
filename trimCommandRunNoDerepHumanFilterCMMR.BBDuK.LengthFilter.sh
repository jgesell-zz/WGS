#!/bin/sh

runs=$1;
length=$2;
mkdir -p ../Logs;
mkdir -p ../Results;
mkdir -p ../QC;
counter=0;

if [ -z "${runs}" ];
then runs=4;
fi;

if [ -z "${length}" ];
then runs=150;
fi;

#Create directory structure and generate the commands
rm ../Scripts/TrimCommand*;
mkdir -p ../Scripts;
mkdir -p ../QC;
for i in `find */raw_data/*_1_sequence.txt.* | xargs du -D -b | sort -k1 -n -r | cut -f2`;
do dir=`echo ${i} | cut -f1 -d "/"`;
outdir="${dir}/processed";
base=`basename ${i} | sed 's/_[0-9]\+_sequence.*//g'`;
pair=`echo ${i} | sed 's/_1_sequence/_2_sequence/'`;
counter=$[counter + 1];
mkdir -p ${outdir};
mkdir -p ${dir}/Logs;
mkdir -p ${dir}/Results;
echo "/gpfs1/projects/mcwong/work/bbmap/bbduk.sh in1=${i} in2=${pair} out1=\${TMPDIR}/${base}.1.Trimmed.fq out2=\${TMPDIR}/${base}.2.Trimmed.fq ref=\${TMPDIR}/Adapters.fasta k=17 hdist=1 minlength=50 qtrim=rl trimq=20 tbo=t tpe=t strictoverlap=f minavgquality=20 maxns=0 entropywindow=20 entropyk=5 mink=10 ktrim=r stats=${dir}/Logs/${base}.TrimmingStats.txt threads=8 minlength=50 overwrite=t qout=33 entropy=.70 ftr=${length} 1>${dir}/Logs/${base}_trimming_report.txt 2>${dir}/Logs/${base}_trimming_report.Error.txt; bowtie2 -x \${TMPDIR}/hg38phix -U \${TMPDIR}/${base}.1.Trimmed.fq,\${TMPDIR}/${base}.2.Trimmed.fq --end-to-end --very-sensitive -p 8 --no-unal --no-hd --mm --no-sq 2> ${dir}/Logs/${base}.hg38phix.align.stats.txt | cut -f1,3 > \${TMPDIR}/${base}.hg38phix.reads.txt; perl /users/mcwong/fastqFilter.pl \${TMPDIR}/${base}.1.Trimmed.fq \${TMPDIR}/${base}.2.Trimmed.fq ${outdir}/${base}_1.fastq.bz2 ${outdir}/${base}_2.fastq.bz2 \${TMPDIR}/${base}.hg38phix.reads.txt; lbzip2 -n8 -c \${TMPDIR}/${base}.hg38phix.reads.txt > ${outdir}/${base}.hg38phix.reads.txt.bz2; rm \${TMPDIR}/${base}.*;";
done | shuf | shuf > ../Scripts/TrimCommand.txt;

#Split the commands for running on multiple compute nodes
split ../Scripts/TrimCommand.txt ../Scripts/TrimCommands -n r/${runs};
jobIDs=$(for i in `find ../Scripts/TrimCommands*`; do echo "cp /gpfs1/projects/mcwong/work/bbmap/resources/adapters.fa \${TMPDIR}/Adapters.fasta; cp /gpfs1/db/hg38phix/hg38phix.*.bt2l \${TMPDIR}; cat ${i} | parallel -j5"| qsub -l ncpus=20 -q batch -d `pwd -P` -V -N Trimming.${i}.Process -o ../Logs -e ../Logs; done | tr -s "\n" ":" | sed -e "s/:$//g");

#Generate Stats for the run
echo -en "Processed Reads:" >> ../QC/Stats.txt;
for i in `ls | sort`; do
echo "count=\`bzcat ${i}/processed/${i}_1.fastq.bz2 | wc -l\`; count=\$[ \$count / 4 ]; echo -en \"\t\${count}\"";
done > ../Scripts/StatCommands.temp;
echo "cat ../Scripts/StatCommands.temp | parallel -j40 -k >> ../QC/Stats.txt; echo '' >> ../QC/Stats.txt; echo -en \"Qtrimmed (Bases):\" >> ../QC/Stats.txt; for i in \`ls | sort\`; do trimmed=\`cat \${i}/Logs/\${i}_trimming_report.Error.txt | grep \"QTrimmed:\" | cut -f3 | cut -f1 -d ' '\`; echo -en \"\t\${trimmed}\" >> ../QC/Stats.txt; done; echo -en \"\nKTrimmed (Bases):\"  >> ../QC/Stats.txt; for i in \`ls | sort\`; do trimmed=\`cat \${i}/Logs/\${i}_trimming_report.Error.txt | grep \"KTrimmed\" | cut -f3 | cut -f1 -d ' '\`; echo -en \"\t\${trimmed}\" >> ../QC/Stats.txt; done; echo ''  >> ../QC/Stats.txt;" | qsub -l ncpus=20 -q batch -d `pwd -P` -V -N Trimming.GetStats -o ../Logs/ -e ../Logs/ -W depend=afterok:${jobIDs};

exit 0;
