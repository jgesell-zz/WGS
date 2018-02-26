#!/bin/sh

export runs=$1;
umask 002;
mkdir -p ../Results;
mkdir -p ../Scripts;

if [ -z "${runs}" ];
then runs=4;
fi;

#Create the Command List for the project
rm ../Scripts/Humann2Command*.Concat*;
for i in `ls`; do echo "lbzcat -n 4 ${i}/processed/${i}_*.fastq.bz2 > \${TMPDIR}/${i}.fastq; mkdir -p \${TMPDIR}/${i}/Results; humann2 --input \${TMPDIR}/${i}.fastq --output \${TMPDIR}/${i}/Results --threads 4 --diamond /gpfs1/projects/mcwong/work/diamond/diamond/bin/ --metaphlan  ~mcwong/work/metaphlan2/metaphlan2/ --bowtie2 /gpfs1/projects/mcwong/newRoot/bin/bowtie2 --usearch /gpfs1/projects/mcwong/newRoot/bin/usearch70 1>${i}/Logs/${i}.Humann2Output.Concat.txt 2>${i}/Logs/${i}.Humann2Error.Concat.txt; mv \${TMPDIR}/${i}/Results/${i}_genefamilies.tsv ${i}/Results/${i}_genefamilies.Concat.tsv & mv \${TMPDIR}/${i}/Results/${i}_pathabundance.tsv ${i}/Results/${i}_pathabundance.Concat.tsv & mv \${TMPDIR}/${i}/Results/${i}_pathcoverage.tsv ${i}/Results/${i}_pathcoverage.Concat.tsv & wait; humann2_renorm_table --input ${i}/Results/${i}_genefamilies.Concat.tsv --output ${i}/Results/${i}_genefamilies_relab.Concat.tsv --units relab & humann2_renorm_table --input ${i}/Results/${i}_pathabundance.Concat.tsv --output ${i}/Results/${i}_pathabundance_relab.Concat.tsv --units relab & humann2_renorm_table --input ${i}/Results/${i}_pathcoverage.Concat.tsv --output ${i}/Results/${i}_pathcoverage_relab.Concat.tsv --units relab & wait; rm -rf \${TMPDIR}/${i} & rm ${i}.fastq & wait;"; done | shuf | shuf > ../Scripts/Humann2Command.Concat.txt;

split ../Scripts/Humann2Command.Concat.txt ../Scripts/Humann2Commands.Concat -n r/${runs};

#Run each of the split files in tandem, and wait for the results before proceding
jobIDs=$(for i in `find ../Scripts/Humann2Commands.Concat*`; do echo "cat ${i} | parallel -j10" | qsub -l ncpus=20 -q batch -d `pwd -P` -V -N `pwd -P | cut -f5,6 -d '/' | sed "s:\/:\.:g"`.${i}.Humann2.Concat -o ../Logs -e ../Logs; done | tr -s "\n" ":" | sed -e "s/:$//g");

#Create the joined table
echo "rsync */Results/*Concat.tsv \${TMPDIR}/; humann2_join_tables --input \${TMPDIR}/ --output `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d "/" | tr "/" "."`.humann2_genefamilies.Concat.tsv --file_name genefamilies_relab.Concat & humann2_join_tables --input \${TMPDIR}/ --output `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d "/" | tr "/" "."`.humann2_pathcoverage.Concat.tsv --file_name pathcoverage_relab.Concat & humann2_join_tables --input \${TMPDIR}/ --output `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d "/" | tr "/" "."`.humann2_pathabundance.Concat.tsv --file_name pathabundance_relab.Concat; for i in \`find ../Results/*.humann2_*.Concat.tsv\`; do biom convert -i \${i} -o \`echo \${i} | sed -e \"s:.tsv:.biom:g\"\` --table-type=\"OTU table\" --to-json; done;" | qsub -l ncpus=3 -q batch -d `pwd -P` -V -N `readlink -e . | cut -f5,6 -d "/" | tr "/" "."`.Humann2.Concat.Process -o ../Logs/ -e ../Logs/ -W depend=afterok:${jobIDs};

#Exit without error
exit 0;
