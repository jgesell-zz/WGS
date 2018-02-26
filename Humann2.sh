#!/bin/sh

export runs=$1;
umask 002;
mkdir -p ../Results;
mkdir -p ../Scripts;

if [ -z "${runs}" ];
then runs=4;
fi;

#Create the Command List for the project
rm ../Scripts/Humann2Command*;
for i in `ls`; do echo "lbzcat -n 4 ${i}/processed/${i}_1.fastq.bz2 > \${TMPDIR}/${i}_1.fastq; humann2 --input \${TMPDIR}/${i}_1.fastq --output ${i}/Results --threads 4 --diamond /gpfs1/projects/mcwong/work/diamond/diamond/bin/ --metaphlan  ~mcwong/work/metaphlan2/metaphlan2/ --bowtie2 /gpfs1/projects/mcwong/newRoot/bin/bowtie2 --usearch /gpfs1/projects/mcwong/newRoot/bin/usearch70 1>${i}/Logs/${i}.Humann2Output.txt 2>${i}/Logs/${i}.Humann2Error.txt; humann2_renorm_table --input ${i}/Results/${i}_1_genefamilies.tsv --output ${i}/Results/${i}_genefamilies_relab.tsv --units relab & humann2_renorm_table --input ${i}/Results/${i}_1_pathabundance.tsv --output ${i}/Results/${i}_pathabundance_relab.tsv --units relab & humann2_renorm_table --input ${i}/Results/${i}_pathcoverage.tsv --output ${i}/Results/${i}_pathcoverage_relab.tsv --units relab & wait; rm \${TMPDIR}/${i}_1.fastq"; done | shuf | shuf > ../Scripts/Humann2Command.txt;

split ../Scripts/Humann2Command.txt ../Scripts/Humann2Commands -n r/${runs};

#Run each of the split files in tandem, and wait for the results before proceding
jobIDs=$(for i in `find ../Scripts/Humann2Commands*`; do echo "cat ${i} | parallel -j10" | qsub -l ncpus=20 -q batch -d `pwd -P` -V -N `pwd -P | cut -f5,6 -d '/' | sed "s:\/:\.:g"`.${i}.Humann -o ../Logs -e ../Logs; done | tr -s "\n" ":" | sed -e "s/:$//g");

#Create the joined table
echo "rsync */Results/*.tsv \${TMPDIR}/; humann2_join_tables --input \${TMPDIR}/ --output `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d "/" | tr "/" "."`.humann2_genefamilies.tsv --file_name genefamilies_relab & humann2_join_tables --input \${TMPDIR}/ --output `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d "/" | tr "/" "."`.humann2_pathcoverage.tsv --file_name pathcoverage_relab & humann2_join_tables --input \${TMPDIR}/ --output `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d "/" | tr "/" "."`.humann2_pathabundance.tsv --file_name pathabundance_relab; for i in \`find ../Results/*.humann2_*.tsv\`; do biom convert -i \${i} -o \`echo \${i} | sed -e \"s:.tsv:.biom:g\"\` --table-type=\"OTU table\" --to-json; done;" | qsub -l ncpus=3 -q batch -d `pwd -P` -V -N `readlink -e . | cut -f5,6 -d "/" | tr "/" "."`.Humann.Process -o ../Logs/ -e ../Logs/ -W depend=afterok:${jobIDs};

#Exit without error
exit 0;
