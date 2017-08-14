#!/bin/sh

runs=$1;
sampleDir=`pwd -P`;
mkdir -p ../Logs;
mkdir -p ../Results;
counter=0;

if [ -z "${runs}" ];
then runs=4;
fi;

for i in `find */raw_data/*_1_sequence.txt.* | xargs du -D -b | sort -k1 -n -r | cut -f2`;
do dir=`echo ${i} | cut -f1 -d "/"`;
filesize=`du -D -b ${i} | cut -f1`;
outdir="${dir}/processed";
base=`basename ${i} | sed 's/_[0-9]\+_sequence.*//g'`;
sample=`echo ${i} | cut -f2 -d "/"`;
pair=`echo ${i} | sed 's/_1_sequence/_2_sequence/'`;
fastq1=`basename ${i} | rev | cut -f2- -d "." | rev`;
fastq2=`basename ${pair} | rev | cut -f2- -d "." | rev`;
counter=$[counter + 1];
mkdir -p ${outdir};
mkdir -p ${dir}/Logs;
mkdir -p ${dir}/Results;
echo "/gpfs1/projects/mcwong/work/bbmap/bbduk.sh in1=${i} in2=${pair} out1=\${TMPDIR}/${base}.1.Trimmed.fq out2=\${TMPDIR}/${base}.2.Trimmed.fq ref=\${TMPDIR}/Adapters.fasta k=17 hdist=1 minlength=50 qtrim=rl trimq=20 tbo=t tpe=t strictoverlap=f minavgquality=20 maxns=0 entropywindow=20 entropyk=5 mink=10 ktrim=r stats=${dir}/Logs/${base}.TrimmingStats.txt threads=8 minlength=50 overwrite=t qout=33 entropy=.70 1>${dir}/Logs/${base}_trimming_report.txt 2>${dir}/Logs/${base}_trimming_report.Error.txt; bowtie2 -x \${TMPDIR}/hg38phix -U \${TMPDIR}/${base}.1.Trimmed.fq,\${TMPDIR}/${base}.2.Trimmed.fq --end-to-end --very-sensitive -p 8 --no-unal --no-hd --mm --no-sq 2> ${dir}/Logs/${base}.hg38phix.align.stats.txt | cut -f1,3 > \${TMPDIR}/${base}.hg38phix.reads.txt; perl /users/mcwong/fastqFilter.pl \${TMPDIR}/${base}.1.Trimmed.fq \${TMPDIR}/${base}.2.Trimmed.fq ${outdir}/${base}_1.fastq.bz2 ${outdir}/${base}_2.fastq.bz2 \${TMPDIR}/${base}.hg38phix.reads.txt; lbzip2 -n8 -c \${TMPDIR}/${base}.hg38phix.reads.txt > ${outdir}/${base}.hg38phix.reads.txt.bz2; rm \${TMPDIR}/${base}* \${TMPDIR}/${fastq1}* \${TMPDIR}/${fastq2}*;";
done > ../TrimCommand.txt;
if [ "${counter}" -lt 20 ];
then echo "cp /users/gesell/Programs/gitHub/WGS/Adapters.fasta \${TMPDIR}/Adapters.fasta; cat ../TrimCommand.txt | parallel -j5" | qsub -l ncpus=20 -q batch -d `pwd -P` -V -N Trimming.Process -o ../Logs -e ../Logs > ../TrimJobs.temp; 
else shuf ../TrimCommand.txt -o ../TrimCommand2;
shuf ../TrimCommand2 -o ../TrimCommand.txt;
rm ../TrimCommand2;
split ../TrimCommand.txt ../TrimCommands -n r/${runs};
for i in `find ../TrimCommands*`; do echo "cp /gpfs1/projects/mcwong/work/bbmap/resources/adapters.fa \${TMPDIR}/Adapters.fasta; cp /gpfs1/db/hg38phix/hg38phix.*.bt2l \${TMPDIR}; cat ${i} | parallel -j5" | qsub -l ncpus=20 -q batch -d `pwd -P` -V -N Trimming.${i}.Process -o ../Logs -e ../Logs > TrimJobs.temp;
done;
fi;
while [ `qstat | grep -f ../TrimJobs.temp | wc -l` -gt 0 ];
do sleep 100;
done;
rm ../TrimJobs.temp;
echo -en "Processed Reads:" >> ../Results/Stats.txt;
for i in `ls | sort`; do 
count=`bzcat ${i}/processed/${i}_1.fastq.bz2 | wc -l`;
count=$[count / 4];
echo -en "\t${count}" >> ../Results/Stats.txt;
done;
echo "" >> ../Results/Stats.txt;
exit 0;
