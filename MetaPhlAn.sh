#!/bin/sh

runs=$1;
umask 002;
mkdir -p ../Results;

if [ -z "${runs}" ];
then runs=4;
fi;

#First, run each sample thru MetaPhlAn on its own
for i in `find */processed/*_1.fastq.bz2`; do home=`pwd -P`; read2=`echo ${i} | sed 's/_1.fastq/_2.fastq/g'`; sample=`echo ${i} | cut -f1 -d "/"`; seq1=`echo ${i} | cut -f3 -d '/' | sed "s:.bz2::g"`; seq2=`echo ${read2} | cut -f3 -d '/' | sed "s:.bz2::g"`; echo "bzcat ${i} > \${TMPDIR}/${seq1} & bzcat ${read2} > \${TMPDIR}/${seq2} & wait; bowtie2 --no-hd --end-to-end --very-sensitive --no-unal -p 10 -x \${TMPDIR}/mpa_v20_m200 -U \${TMPDIR}/${seq1},\${TMPDIR}/${seq2} --end-to-end --very-sensitive --no-unal 2>${sample}/Logs/${sample}.MetaPhlAn2.Input | cut -f1,3 | /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/metaphlan2.py --input_type bowtie2out --nproc 10 --mpa_pkl \${TMPDIR}/mpa_v20_m200.pkl -s ${sample}/Results/${i}.MetaPhlan2.sam | grep -v \"#\" | perl ~/Programs/ToTest/convertSingleMetaPhlAnToFormat.pl > ${sample}/Results/${sample}_profile.txt"; done > ../MetaPhlAnCommand.txt; 

#Shuffle the commands
shuf ../MetaPhlAnCommand.txt > ../MetaPhlAnCommand.txt2; 
shuf ../MetaPhlAnCommand.txt2 > ../MetaPhlAnCommand.txt; 
rm ../MetaPhlAnCommand.txt2; 
split ../MetaPhlAnCommand.txt ../MetaPhlAnCommands -n r/${runs} && rm ../MetaPhlAnCommand.txt;

#Run the commands in parallel
for i in `ls .. | grep MetaPhlAnCommands`; do echo "cp /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/db_v20/mpa_v20_m200*.bt2 \${TMPDIR}/; cp /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/db_v20/mpa_v20_m200.pkl.bz2 \${TMPDIR}/; cd \${TMPDIR}; pbzip2 -d mpa_v20_m200.pkl.bz2; cd ${home}; cat ../${i} | parallel -I {} -j4;" | qsub -l ncpus=20 -q batch -N `pwd -P | cut -f5,6 -d '/' | sed "s:\/:\.:g"`.Process -d `pwd -P` -V -o ../Logs/ -e ../Logs/ >> ../MetaPhlAnjobIDs.temp; done;
while [ `qstat | grep -f ../MetaPhlAnjobIDs.temp | wc -l` -gt 0 ];
do sleep 100;
done;
rm ../MetaPhlAnjobIDs.temp;
mv ../MetaPhlAnCommands* ../Logs/;

#Next, merge and put resulting tables into Results directory
~mcwong/work/metaphlan2/metaphlan2/utils/merge_metaphlan_tables.py */Results/*_profile.txt > ../Results/MergedAbundanceTable.txt;
biom convert -i ../Results/MergedAbundanceTable.txt -o ../Results/MergedAbundanceTable.biom --table-type="OTU table" --to-json;

#Exit assuming no errors
exit 0;
