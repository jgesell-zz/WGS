#!/bin/sh

export runs=$1;
umask 002;
mkdir -p ../Results;
mkdir -p ../Scripts;

if [ -z "${runs}" ];
then runs=4;
fi;

for i in `find ../Scripts/MetaPhlAnCommand*.BaceriaOnly* | grep -v Gallus`; do rm ${i}; done;
home=`pwd -P`;

#First, run each sample thru MetaPhlAn on its own
for i in `find */processed/*_1.fastq.bz2`; do home=`pwd -P`; read2=`echo ${i} | sed 's/_1.fastq/_2.fastq/g'`; sample=`echo ${i} | cut -f1 -d "/"`; seq1=`echo ${i} | cut -f3 -d '/' | sed "s:.bz2::g"`; seq2=`echo ${read2} | cut -f3 -d '/' | sed "s:.bz2::g"`; echo "lbzcat ${i} -n 2 > \${TMPDIR}/${seq1} & lbzcat ${read2} -n 2 > \${TMPDIR}/${seq2} & wait; bowtie2 --no-hd --end-to-end --very-sensitive --no-unal -p 4 -x \${TMPDIR}/mpa_v20_m200 -U \${TMPDIR}/${seq1},\${TMPDIR}/${seq2} --end-to-end --very-sensitive --no-unal 2>${sample}/Logs/${sample}.MetaPhlAn2.BaceriaOnly.Input | tee ${sample}/Results/${sample}.MetaPhlAn2.Bowtie2.out | cut -f1,3 | /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/metaphlan2.py --input_type bowtie2out --ignore_eukaryotes --ignore_viruses --ignore_archaea --nproc 4 --mpa_pkl \${TMPDIR}/mpa_v20_m200.pkl -s ${sample}/Results/${sample}.MetaPhlan2.BaceriaOnly.sam | grep -v \"#\" | perl ~/Programs/ToTest/convertSingleMetaPhlAnToFormat.pl > ${sample}/Results/${sample}_profile.BaceriaOnly.txt"; done | shuf | shuf > ../Scripts/MetaPhlAnCommand.BaceriaOnly.txt;

#Shuffle the commands
split ../Scripts/MetaPhlAnCommand.BaceriaOnly.txt ../Scripts/MetaPhlAnCommands.BaceriaOnly -n r/${runs};

#Run the commands in parallel
jobIDs=$(for i in `find ../Scripts/MetaPhlAnCommands.BaceriaOnlya*`; do echo "cp /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/db_v20/mpa_v20_m200*.bt2* \${TMPDIR}/ & cp /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/db_v20/mpa_v20_m200.pkl \${TMPDIR}/ & wait;cat ${i} | parallel -j10;" | qsub -l ncpus=20 -q batch -N `pwd -P | cut -f5,6 -d '/' | sed "s:\/:\.:g"`.${i}.MetaPhlAn2.BaceriaOnly -d `pwd -P` -V -o ../Logs -e ../Logs; done | tr -s "\n" ":" | sed -e "s/:$//g");

#Next, merge and put resulting tables into Results directory
echo "~mcwong/work/metaphlan2/metaphlan2/utils/merge_metaphlan_tables.py */Results/*_profile.BaceriaOnly.txt > `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d '/' | tr '/' '.'`.MergedAbundanceTable.BaceriaOnly.txt; biom convert -i `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d '/' | tr '/' '.'`.MergedAbundanceTable.BaceriaOnly.txt -o `readlink -e ../Results`/`readlink -e . | cut -f5,6 -d '/' | tr '/' '.'`.MergedAbundanceTable.BaceriaOnly.biom --table-type=\"OTU table\" --to-json;" | qsub -l ncpus=1 -q batch -d `pwd -P` -V -N MetaPhlAn2.BaceriaOnly.MergeTables -o ../Logs/ -e ../Logs/ -W depend=afterok:${jobIDs};

#Exit assuming no errors
exit 0;
