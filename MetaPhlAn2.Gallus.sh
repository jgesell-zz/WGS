#!/bin/sh

export runs=$1;
umask 002;
mkdir -p ../Results;
mkdir -p ../Logs/;
mkdir -p ../Scripts;

if [ -z "${runs}" ];
then runs=4;
fi;

export RESULTS=`readlink -e ../Results`;
export PREFIX=`readlink -e . | cut -f5,6 -d '/' | tr '/' '.'`;

for i in `find ../Scripts/MetaPhlAn.Gallus.BowtieGenerationCommand*`; do rm ${i}; done;
for i in `find ../Scripts/MetaPhlAn2.Gallus.Command*`; do rm ${i}; done;

#First, run each sample thru BowTie2 to generate the MetaPhlAn2 inputs
for i in `find */processed/*_1.fastq.bz2`; do read2=`echo ${i} | sed 's/_1.fastq/_2.fastq/g'`; sample=`echo ${i} | cut -f1 -d "/"`; seq1=`echo ${i} | cut -f3 -d '/' | sed "s:.bz2::g"`; seq2=`echo ${read2} | cut -f3 -d '/' | sed "s:.bz2::g"`; echo "lbzcat -n 2 ${i} > \${TMPDIR}/${seq1} & lbzcat -n 2 ${read2} > \${TMPDIR}/${seq2} & wait; bowtie2 --no-hd --end-to-end --very-sensitive --no-unal -p 4 -x \${TMPDIR}/mpa_v20_m200 -U \${TMPDIR}/${seq1},\${TMPDIR}/${seq2} --end-to-end --very-sensitive --no-unal 2>${sample}/Logs/${sample}.Gallus.MetaPhlAn2.Input > ${sample}/Results/${sample}.Gallus.MetaPhlAn2.Bowtie2.out"; done | shuf | shuf | shuf > ../Scripts/MetaPhlAn.Gallus.BowtieGenerationCommand.txt; 

#Split the generation scripts and run according to the number of requested splits
split ../Scripts/MetaPhlAn.Gallus.BowtieGenerationCommand.txt ../Scripts/MetaPhlAn.Gallus.BowtieGenerationCommands -n r/${runs};
jobIDs=$(for i in `find ../Scripts/MetaPhlAn.Gallus.BowtieGenerationCommands*`; do echo "cp /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/db_v20/mpa_v20_m200* \${TMPDIR}/; cat ${i} | parallel -j10;" | qsub -l ncpus=20 -q batch -N `pwd -P | cut -f5,6 -d '/' | sed "s:\/:\.:g"`.${i}.Gallus.MetaPhlAn2.Gallus.BowTie2Generation -d `pwd -P` -V -o ../Logs/ -e ../Logs/; done | tr -s "\n" ":" | sed -e "s/:$//g");

#Next, generate the scripts to run MetaPhlAn2 based on Kingdoms
for i in `ls`; do echo "cat ${i}/Results/${i}.Gallus.MetaPhlAn2.Bowtie2.out | cut -f1,3 > \${TMPDIR}/${i}.Gallus.MetaPhlAn2.Bowtie2.Trimmed.out; cat \${TMPDIR}/${i}.Gallus.MetaPhlAn2.Bowtie2.Trimmed.out | /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/metaphlan2.py --input_type bowtie2out --nproc 2 --mpa_pkl \${TMPDIR}/mpa_v20_m200.pkl -s ${i}/Results/${i}.Gallus.All.MetaPhlan2.sam | tee ${i}/Results/${i}.Gallus.All_profile.raw.txt | grep -v \"#\" | perl ~/Programs/ToTest/convertSingleMetaPhlAnToFormat.pl > ${i}/Results/${i}.Gallus.All_profile.txt & cat \${TMPDIR}/${i}.Gallus.MetaPhlAn2.Bowtie2.Trimmed.out | /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/metaphlan2.py --input_type bowtie2out --nproc 2 --ignore_eukaryotes --ignore_viruses --ignore_archaea --mpa_pkl \${TMPDIR}/mpa_v20_m200.pkl -s ${i}/Results/${i}.Gallus.BacteriaOnly.MetaPhlan2.sam | tee ${i}/Results/${i}.Gallus.BacteriaOnly_profile.raw.txt | grep -v \"#\" | perl ~/Programs/ToTest/convertSingleMetaPhlAnToFormat.pl > ${i}/Results/${i}.Gallus.BacteriaOnly_profile.txt & cat \${TMPDIR}/${i}.Gallus.MetaPhlAn2.Bowtie2.Trimmed.out | /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/metaphlan2.py --input_type bowtie2out --nproc 2 --ignore_eukaryotes --ignore_viruses --ignore_bacteria --mpa_pkl \${TMPDIR}/mpa_v20_m200.pkl -s ${i}/Results/${i}.Gallus.ArchaeaOnly.MetaPhlan2.sam | tee ${i}/Results/${i}.Gallus.ArchaeaOnly_profile.raw.txt | grep -v \"#\" | perl ~/Programs/ToTest/convertSingleMetaPhlAnToFormat.pl > ${i}/Results/${i}.Gallus.ArchaeaOnly_profile.txt & cat \${TMPDIR}/${i}.Gallus.MetaPhlAn2.Bowtie2.Trimmed.out | /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/metaphlan2.py --input_type bowtie2out --nproc 2 --ignore_eukaryotes --ignore_bacteria --ignore_archaea --mpa_pkl \${TMPDIR}/mpa_v20_m200.pkl -s ${i}/Results/${i}.Gallus.VirusesOnly.MetaPhlan2.sam | tee ${i}/Results/${i}.Gallus.VirusesOnly_profile.raw.txt | grep -v \"#\" | perl ~/Programs/ToTest/convertSingleMetaPhlAnToFormat.pl > ${i}/Results/${i}.Gallus.VirusesOnly_profile.txt & cat \${TMPDIR}/${i}.Gallus.MetaPhlAn2.Bowtie2.Trimmed.out | /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/metaphlan2.py --input_type bowtie2out --nproc 2 --ignore_bacteria --ignore_viruses --ignore_archaea --mpa_pkl \${TMPDIR}/mpa_v20_m200.pkl -s ${i}/Results/${i}.Gallus.EukaryotesOnly.MetaPhlan2.sam | tee ${i}/Results/${i}.Gallus.EukaryotesOnly_profile.raw.txt | grep -v \"#\" | perl ~/Programs/ToTest/convertSingleMetaPhlAnToFormat.pl > ${i}/Results/${i}.Gallus.EukaryotesOnly_profile.txt & wait;"; done | shuf | shuf > ../Scripts/MetaPhlAn2.Gallus.Command.txt

#Split the MetaPhlAn2 commands, just like the Bowtie commands
split ../Scripts/MetaPhlAn2.Gallus.Command.txt ../Scripts/MetaPhlAn2.Gallus.Commands -n r/${runs};

#Run the MetaPhlAn2 commands in parallel
jobIDs2=$(for i in `find ../Scripts/MetaPhlAn2.Gallus.Commands*`; do echo "cp /gpfs1/projects/mcwong/work/metaphlan2/metaphlan2/db_v20/mpa_v20_m200* \${TMPDIR}/; cat ${i} | parallel -j5;" | qsub -l ncpus=20 -q batch -N `pwd -P | cut -f5,6 -d '/' | sed "s:\/:\.:g"`.${i}.Gallus.MetaPhlAn2 -d `pwd -P` -V -o ../Logs/ -e ../Logs/ -W depend=afterok:${jobIDs}; done | tr -s "\n" ":" | sed -e "s/:$//g");


#Next, merge and put resulting tables into Results directory
echo "for j in {All,ArchaeaOnly,BacteriaOnly,EukaryotesOnly,VirusesOnly}; do ~mcwong/work/metaphlan2/metaphlan2/utils/merge_metaphlan_tables.py */Results/*.Gallus.\${j}_profile.txt > ${RESULTS}/${PREFIX}.Gallus.\${j}.MergedAbundanceTable.txt; biom convert -i ${RESULTS}/${PREFIX}.Gallus.\${j}.MergedAbundanceTable.txt -o ${RESULTS}/${PREFIX}.Gallus.\${j}.MergedAbundanceTable.tmp --table-type=\"OTU table\" --to-json; cat ${RESULTS}/${PREFIX}.Gallus.\${j}.MergedAbundanceTable.tmp | ${GITREPO}/WGS/fixMetaphlanTaxaField.pl > ${RESULTS}/${PREFIX}.Gallus.\${j}.MergedAbundanceTable.biom && rm ${RESULTS}/${PREFIX}.Gallus.\${j}.MergedAbundanceTable.tmp; done;" | qsub -l ncpus=3 -q batch -d `pwd -P` -V -N MetaPhlAn2.MergeTables -o ../Logs/ -e ../Logs/ -W depend=afterok:${jobIDs2};

#Exit assuming no errors
exit 0;
