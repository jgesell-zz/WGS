#!/bin/sh

runs=$1;
mkdir -p ../QC;
mkdir -p ../Logs;

if [ -z "${runs}" ];
then runs=4;
fi;

rm ../Logs/FastQCProcessed.Command*;

for i in `ls`; do echo "mkdir -p \${TMPDIR}/${i}.1 & mkdir -p \${TMPDIR}/${i}.2 & wait; lbzcat -n2 ${i}/processed/${i}_1.fastq.bz2 | fastqc -o \${TMPDIR}/${i}.1 stdin & lbzcat -n2 ${i}/processed/${i}_2.fastq.bz2 | fastqc -o \${TMPDIR}/${i}.2 stdin & wait;  cat \${TMPDIR}/${i}.1/stdin_fastqc.html | sed -e \"s:stdin:${i}_1.fastq.bz2:g\" > ../QC/${i}.1_fastqc.Processed.html & cat \${TMPDIR}/${i}.2/stdin_fastqc.html | sed -e \"s:stdin:${i}_2.fastq.bz2:g\" > ../QC/${i}.2_fastqc.Processed.html & mv \${TMPDIR}/${i}.1/stdin_fastqc.html.2 ../QC/${i}.1_fastqc.Processed.html & mv \${TMPDIR}/${i}.1/stdin_fastqc.zip ../QC/${i}.1_fastqc.Processed.zip & mv \${TMPDIR}/${i}.2/stdin_fastqc.zip ../QC/${i}.2_fastqc.Processed.zip & wait;"; done > ../Logs/FastQCProcessed.Command;
shuf ../Logs/FastQCProcessed.Command > ../Logs/FastQCProcessed.Command2;
shuf ../Logs/FastQCProcessed.Command2 > ../Logs/FastQCProcessed.Command;
rm ../Logs/FastQCProcessed.Command2;
split ../Logs/FastQCProcessed.Command ../Logs/FastQCProcessed.Commands -n r/${runs};
for i in `find ../Logs/FastQCProcessed.Commands*`; do echo "cat ${i} | parallel -j2" | qsub -l ncpus=6 -q batch -d `pwd -P` -V -N ${i}.FastQCProcessed -o ../Logs/ -e ../Logs/; done;
exit 0;
