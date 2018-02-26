#!/bin/sh

export runs=$1;
umask 002;
mkdir -p ../Results;
mkdir -p ../Logs;
mkdir -p ../Scripts;

if [ -z "${runs}" ];
then runs=4;
fi;

home=`pwd -P`;

for i in `find ../Scripts/GallusMetaPhlAnCommand* | grep -v "Bacteria"`; do rm ${i}; done;

#First, run each sample thru MetaPhlAn on its own
for i in `find */processed/*Gallus_1.fastq.bz2`; do home=`pwd -P`; read2=`echo ${i} | sed 's/_1.fastq/_2.fastq/g'`; sample=`echo ${i} | cut -f1 -d "/"`; seq1=`echo ${i} | cut -f3 -d '/' | sed "s:.bz2::g"`; seq2=`echo ${read2} | cut -f3 -d '/' | sed "s:.bz2::g"`; echo "lbzcat -n 2 ${i} > \${TMPDIR}/${seq1} & lbzcat -n 2 ${read2} > \${TMPDIR}/${seq2} & wait; bowtie2 --no-hd --end-to-end --very-sensitive --no-unal -p 4 -x \${TMPDIR}/mpa_v20_m200 -U \${TMPDIR}/${seq1},\${TMPDIR}/${seq2} --end-to-end --very-sensitive --no-unal 2>${sample}/Logs/${sample}.Gallus.MetaPhlAn2.Input | tee ${sample}/Results/${sample}.MetaPhlAn2.Bowtie2.out | cut -f1,3 | /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/metaphlan2.py --input_type bowtie2out --nproc 4 --mpa_pkl \${TMPDIR}/mpa_v20_m200.pkl -s ${sample}/Results/${sample}.Gallus.MetaPhlan2.sam | tee ${sample}/Results/${sample}_profile.Gallus.raw.txt | grep -v \"#\" | perl ~/Programs/ToTest/convertSingleMetaPhlAnToFormat.pl > ${sample}/Results/${sample}_profile.Gallus.txt"; done | shuf | shuf | shuf > ../Scripts/GallusMetaPhlAnCommand.txt; 

#Shuffle the commands
split ../Scripts/GallusMetaPhlAnCommand.txt ../Scripts/GallusMetaPhlAnCommands -n r/${runs};

#Run the commands in parallel
jobIDs=$(for i in `find ../Scripts/GallusMetaPhlAnCommands* | grep -v "Bacteria"`; do echo "cp /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/db_v20/mpa_v20_m200*.bt2* \${TMPDIR}/ & cp /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/db_v20/mpa_v20_m200.pkl \${TMPDIR}/ & wait; cat ${i} | parallel -j10;" | qsub -l ncpus=20 -q batch -N `pwd -P | cut -f5,6 -d '/' | sed "s:\/:\.:g"`.${i}.Gallus.MetaPhlAn2 -d `pwd -P` -V -o ../Logs -e ../Logs; done | tr -s "\n" ":" | sed -e "s/:$//g");

#Next, merge and put resulting tables into Results directory
echo "~mcwong/work/metaphlan2/metaphlan2/utils/merge_metaphlan_tables.py */Results/*_profile.Gallus.txt > `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d '/' | tr '/' '.'`.Gallus.MergedAbundanceTable.txt; biom convert -i `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d '/' | tr '/' '.'`.Gallus.MergedAbundanceTable.txt -o `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d '/' | tr '/' '.'`.Gallus.MergedAbundanceTable.tmp --table-type=\"OTU table\" --to-json; cat `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d '/' | tr '/' '.'`.Gallus.MergedAbundanceTable.tmp | ${GITREPO}/WGS/fixMetaphlanTaxaField.pl > `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d '/' | tr '/' '.'`.Gallus.MergedAbundanceTable.biom && rm `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d '/' | tr '/' '.'`.Gallus.MergedAbundanceTable.tmp" | qsub -l ncpus=1 -q batch -d `pwd -P` -V -N MetaPhlAn2.MergeTables -o ../Logs/ -e ../Logs/ -W depend=afterok:${jobIDs};

#Exit assuming no errors
exit 0;
