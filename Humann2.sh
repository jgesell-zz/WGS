#!/bin/sh

export splits=$1;

if [ -z "${splits}" ];
then export splits=4;
fi;

umask 002;
mkdir -p ../Results;

#Create the Command List for the project
for i in `ls`; do echo "bzcat ${i}/processed/${i}_1.fastq.bz2 > \${TMPDIR}/${i}_1.fastq; humann2 --input \${TMPDIR}/${i}_1.fastq --output ${i}/Results --threads 8 --diamond /gpfs1/projects/mcwong/work/diamond/diamond/bin/ --metaphlan  ~mcwong/work/metaphlan2/metaphlan2/ --bowtie2 /gpfs1/projects/mcwong/newRoot/bin/bowtie2 --usearch /gpfs1/projects/mcwong/newRoot/bin/usearch70 1>${i}/Logs/${i}.Humann2Output.txt 2>${i}/Logs/${i}.Humann2Error.txt; humann2_renorm_table --input ${i}/Results/${i}_1_genefamilies.tsv --output ${i}/Results/${i}_genefamilies_relab.tsv --units relab & humann2_renorm_table --input ${i}/Results/${i}_1_pathabundance.tsv --output ${i}/Results/${i}_pathabundance_relab.tsv --units relab & wait; rm \${TMPDIR}/${i}*"; done > ../Humann2Command.txt;

#Split the command list based on the number of simultaneous threads
shuf ../Humann2Command.txt > ../Humann2Command.txt2;
shuf ../Humann2Command.txt2 > ../Humann2Command.txt;
rm ../Humann2Command.txt2;
split ../Humann2Command.txt ../Humann2Commands -n r/${splits};

#Run each of the split files in tandem, and wait for the results before proceding
for i in `find ../Humann2Commands*`; do echo "cat ${i} | parallel -j5" | qsub -l ncpus=20  -q batch -d `pwd -P` -V -N `readlink -e . | cut -f5,6 -d "/" | tr "/" "."`${i}.Humann -o ../Logs/ -e ../Logs/ >> ../HumannjobIDs.temp; done;
while [ `qstat | grep -f ../HumannjobIDs.temp | wc -l` -gt 0 ];
do sleep 100;
done;
rm ../HumannjobIDs.temp;

#Create the joined table
echo "rsync */Results/*.tsv \${TMPDIR}/; humann2_join_tables --input \${TMPDIR}/ --output `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d "/" | tr "/" "."`.humann2_genefamilies.tsv --file_name genefamilies_relab & humann2_join_tables --input \${TMPDIR}/ --output `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d "/" | tr "/" "."`.humann2_pathcoverage.tsv --file_name pathcoverage & humann2_join_tables --input \${TMPDIR}/ --output `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d "/" | tr "/" "."`.humann2_pathabundance.tsv --file_name pathabundance_relab;" | qsub -l ncpus=3 -q batch -d `pwd -P` -V -N `readlink -e . | cut -f5,6 -d "/" | tr "/" "."`.Humann.Process -o ../Logs/ -e ../Logs/ > ../HumannjobIDs.temp;
while [ `qstat | grep -f ../HumannjobIDs.temp | wc -l` -gt 0 ];
do sleep 100;
done;
rm ../HumannjobIDs.temp;
mv ../Humann2Commands* ../Logs/;

#Convert the table to a json-formatted biom file
for i in `find ../Results/*.humann2_*.tsv`; do biom convert -i ${i} -o `echo ${i} | sed -e "s:.tsv:.biom:g"` --table-type="OTU table" --to-json; done;

#Exit without error
exit 0;
