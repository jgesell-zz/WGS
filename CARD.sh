#!/bin/sh

umask 002;
mkdir -p ../Results;

#Run the samples against the four CARD types in parallel, and wait for the jobs to finish;
for i in `ls`; do read1=`readlink -e ${i}/processed/${i}_1.fastq.bz2`; read2=`echo ${read1} | sed -e "s:_1.fastq.bz2:_2.fastq.bz2:g"`; seq1=`echo ${read1} | rev | cut -f1 -d "/" | rev | sed -e "s:.bz2::g"`; seq2=`echo ${read2} | rev | cut -f1 -d "/" | rev | sed -e "s:.bz2::g"`; echo "lbzcat ${read1} > \${TMPDIR}/${seq1} & lbzcat ${read2} > \${TMPDIR}/${seq2} & wait; for j in {CARD.ProteinKnockoutModel,CARD.ProteinWildTypeModel,CARD.ProteinVariantModel,CARD.ProteinHomologModel}; do bowtie2 --mm --no-hd --end-to-end --very-sensitive --no-unal -p8 --reorder -x \${TMPDIR}/\${j} -1 \${TMPDIR}/${seq1} -2 \${TMPDIR}/${seq2} --no-sq 2>`readlink -e ${i}`/Results/${i}.\${j}.SequenceAlignments.txt | lbzip2 -f -c > `readlink -e ${i}`/Results/${i}.\${j}.sam.bz2; done;";done > ../CARDCommand.txt;
shuf ../CARDCommand.txt > ../CARDCommand.txt2; shuf ../CARDCommand.txt2 > ../CARDCommand.txt; rm ../CARDCommand.txt2; split ../CARDCommand.txt ../CARDCommands -n r/4;
for i in `find ../CARDCommands*`; do echo "rsync -aL /gpfs1/db/CARD/*.bt2 \${TMPDIR}; cat ${i} | parallel -j5;" | qsub -l ncpus=20 -q batch -d `pwd -P` -V -N CARD.Process.${i} -o ../Logs/ -e ../Logs/; done > ../jobIDs.temp;
while [ `qstat | grep -f ../jobIDs.temp | wc -l` -gt 0 ]; 
do sleep 100;
done;
rm ../jobIDs.temp;

#Create the Deliverables for the CARD outputs
echo -n "Card Database" > ../Results/CARDHitsPerSample.tsv; for i in `ls`; do echo -en "\t${i}" >>  ../Results/CARDHitsPerSample.tsv; done; 
echo "" >>  ../Results/CARDHitsPerSample.tsv; for j in {CARD.ProteinKnockoutModel,CARD.ProteinWildTypeModel,CARD.ProteinVariantModel,CARD.ProteinHomologModel}; do echo -en "${j}" >> ../Results/CARDHitsPerSample.tsv; echo "for i in \`ls\`; do echo -en \"\t`lbzcat ${i}/Results/${i}.${j}.sam.bz2 | wc -l`\" >>  ../Results/CARDHitsPerSample.tsv; done; echo \"\" >> ../Results/CARDHitsPerSample.tsv; bzcat */Results/*.${j}.sam.bz2 | cut -f3 | sort | uniq > ../Results/${j}.UniqueHits.txt; lbzcat */Results/*.${j}.sam.bz2 | cut -f3 | sort | uniq > ../Results/${j}.UniqueHits.txt; perl ~/Programs/ToTest/CARD.SamHitsPerSample.pl --hitList \"../Results/${j}.UniqueHits.txt\" --samFilePrefix \"${j}\" > ../Results/${j}.HitsPerSample.tsv; biom convert -i ../Results/${j}.HitsPerSample.tsv -o ../Results/${j}.biom --table-type=\"OTU table\" --to-json --header-key taxonomy"; done > ../CARD.RefineCommand.txt; echo "cat ../CARD.RefineCommand.txt | parallel -j4" | qsub -l ncpus=4 -q batch -d `pwd -P` -V -N CARDSamples.Refine -o ../Logs/ -e ../Logs/ > ../jobIDs.temp;
while [ `qstat | grep -f ../jobIDs.temp | wc -l` -gt 0 ];
do sleep 100;
done;
rm ../jobIDs.temp;

#Exit assuming no errors above
exit 0;
