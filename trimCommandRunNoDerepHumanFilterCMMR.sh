#/bin/sh

cores=$1;
if [ -z "${cores}" ];
then cores=4;
fi;

sampleDir=`pwd -P`;
mkdir -p ../Logs;
mkdir -p ../Results;
counter=0;
for i in `find */raw_data/*.bz2 | grep "_1_sequence" | xargs du -D -b | sort -k1 -n -r  | cut -f2`; 
do dir=`echo ${i} | cut -f1 -d "/"`;
filesize=`du -D -b ${i} | cut -f1`;
outdir="${dir}/processed"; 
base=`basename ${i} | sed 's/_[0-9]\+_sequence.*//g'`; 
sample=`echo ${i} | cut -f2 -d "/"`; 
pair=`echo ${i} | sed 's/_1_sequence/_2_sequence/'`; 
fastq1=`basename ${i}`; 
fastq2=`basename ${pair}`;
counter=$[counter + 1];
mkdir -p $outdir;
mkdir -p ${dir}/Logs;
mkdir -p ${dir}/Results;
echo "cp ${i} ${pair} \$TMPDIR; threaded_bz2trim_galore -q 20 --stringency 6 --length 50 --paired --retain_unpaired --length_1 51 --length_2 51 --bzip --adapter AGATCGGAAGAGC,GCTCTTCCGATCT,TCGGACTGTAGAACTCTGAACCTGTCGGTGGTCGCCGTATCATT,TCGGACTGTAGAACTCTGAACGTGTAGATCTCGGTGGTCGCCGTATCATT,AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTCGCCGTATCATT,AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT,GTCGGACTGTAGAACTCTGAACCTGT,CAAGCAGAAGACGGCATACGAGAT,GTATGCCGTCTTCTGCTTG,CATGTCGGACTGTAGAACTCTGAACCTGTCGG,GATCGTCGGACTGTAGAACTCTGAACCTGTCG,AGATCGGAAGAGCGGTTCAGCAGGAATGCCGAGACCG,GAACTCCAGTC,GCTCTTCCGATC,GTTCAGAGTTCTACAGTCCGACGATC,TGGAATTCTCGGGTGCCAAGGC,GATCGGAAGAGCACACGTCTGAACTCCAGTCAC,TGGAATTCTCGGGTGCCAAGGAACTCCAGTCAC,GATCGTCGGACTGTAGAACTCTGAAC,GTTCAGAGTTCTACAGTCCGA,CAAGCAGAAGACGGCATAC,CCTTGGCACCCGAGAATTCCA,AATGATACGGCGACCACCGACAGGTTCAGAGTTCTACAGTCCGA,AATGATACGGCGACCACCGAGATCTACACGTTCAGAGTTCTACAGTCCGA,AATGATACGGCGACCACCGAGATCTACACTCTTTCCCTACACGACGCTCTTCCGATCT,ACACTCTTTCCCTACACGACGCTCTTCCGATCT,ACAGGTTCAGAGTTCTACAGTCCGAC,ATCTCGTATGCCGTCTTCTGCTTG,CAAGCAGAAGACGGCATAC,CCGACAGGTTCAGAGTTCTACAGTCCGACATG,CGACAGGTTCAGAGTTCTACAGTCCGACGATC,CGGTCTCGGCATTCCTGCTGAACCGCTCTTCCGATCT,GACTGGAGTTC,GATCGGAAGAGC,GATCGTCGGACTGTAGAACTCTGAAC,GCCTTGGCACCCGAGAATTCCA,GTGACTGGAGTTCAGACGTGTGCTCTTCCGATCT,GTGACTGGAGTTCCTTGGCACCCGAGAATTCCA,GTTCAGAGTTCTACAGTCCGACGATC,TCGGACTGTAGAACTCTGAAC,GTATGCCGTCTTCTGCTTG,TGGAATTCTCGGGTGCCAAGG,CAGACGTGTGCTCTTCCGATC,GATCGGAAGAGCACACGTCTG -o \${TMPDIR} \${TMPDIR}/${fastq1} \${TMPDIR}/${fastq2}; cp \${TMPDIR}/${fastq2}_val_2.fq.bz2 \${TMPDIR}/${fastq1}_val_1.fq.bz2 ${outdir}; bz2prinseq -fastq \${TMPDIR}/${fastq1}_val_1.fq.bz2 -fastq2 \${TMPDIR}/${fastq2}_val_2.fq.bz2 -out_good \${TMPDIR}/${base} -out_bad \${TMPDIR}/${base}.bad -log \${TMPDIR}/${base}.log -no_qual_header -lc_method dust -lc_threshold 5 -trim_ns_left 1 -trim_ns_right 1; mv \${TMPDIR}/${base}_1.fastq.bz2 \${TMPDIR}/${base}_1.pre.fastq.bz2; mv \${TMPDIR}/${base}_2.fastq.bz2 \${TMPDIR}/${base}_2.pre.fastq.bz2; bowtie2 -x /gpfs1/db/hg38phix/hg38phix -U \${TMPDIR}/${base}_1.pre.fastq.bz2,\${TMPDIR}/${base}_1.pre.fastq.bz2 --end-to-end --very-sensitive -p 8 --no-unal --no-hd --no-sq 2> \${TMPDIR}/${base}.hg38phix.align.stats.txt | cut -f1,3 > \${TMPDIR}/${base}.hg38phix.reads.txt; perl /users/mcwong/fastqFilter.pl \${TMPDIR}/${base}_1.pre.fastq.bz2 \${TMPDIR}/${base}_2.pre.fastq.bz2 \${TMPDIR}/${base}_1.fastq.bz2 \${TMPDIR}/${base}_2.fastq.bz2 \${TMPDIR}/${base}.hg38phix.reads.txt; rm \${TMPDIR}/${base}_1.pre.fastq.bz2; rm \${TMPDIR}/${base}_2.pre.fastq.bz2; rm \${TMPDIR}/${fastq1}_val_1.fq.bz2; rm \${TMPDIR}/${fastq2}_val_2.fq.bz2; cp \${TMPDIR}/${base}_1.fastq.bz2 \${TMPDIR}/${base}_2.fastq.bz2 \${TMPDIR}/${base}.hg38phix.reads.txt \${TMPDIR}/${base}.log \${TMPDIR}/${base}.hg38phix.align.stats.txt \${TMPDIR}/${base}*_trimming_report.txt ${outdir}/";
done > ../TrimCommand.txt;
if [ $counter -lt 20 ]; 
then echo "cat ../TrimCommand.txt | parallel -j5" | qsub -l ncpus=20 -q batch -d `pwd -P` -V -N Trimming.Process -o ../Logs -e ../Logs;
else shuf ../TrimCommand.txt -o ../TrimCommand2;
shuf ../TrimCommand2 -o ../TrimCommand.txt;
rm ../TrimCommand2;
split ../TrimCommand.txt ../TrimCommands -n r/${cores};
for i in `find ../TrimCommands`; do echo "cat ${i} | parallel -j5" | qsub -l ncpus=20 -q batch -d `pwd -P` -V -N Trimming.${i}.Process -o ../Logs -e ../Logs;
done;
fi;
exit 0;
