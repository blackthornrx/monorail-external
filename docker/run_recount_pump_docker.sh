#make sure singularity is loaded/in $PATH
umask 0077
export PERL5LIB=

#run accession (sra, e.g. SRR390728), or internal ID (local), 
#this can be anything as long as its consistently used to identify the particular sample
run_acc=$1
#"local" or the SRA study accession (e.g. SRP020237) if downloading from SRA
study=$2
#"hg38" (human) or "grcm38" (mouse)
ref_name=$3
#number of processes to start within container, 4-16 are reasonable depending on the system/run
num_cpus=$4
#full path to location of downloaded refs
#this directory should contain either "hg38" or "grcm38" subdirectories (or both)
ref_path=$5

#full file path to first read mates (optional)
fp1=$7
#full file path to second read mates (optional)
fp2=$8

export RECOUNT_JOB_ID=${run_acc}_in0_att0

#assumes these directories are subdirs in current working directory
export RECOUNT_INPUT_HOST=/home/ubuntu/input/${run_acc}_att0
#RECOUNT_OUTPUT_HOST stores the final set of files and some of the intermediate files while the process is running.
export RECOUNT_OUTPUT_HOST=/home/ubuntu/output/${run_acc}_att0
#RECOUNT_TEMP_HOST stores the initial download of sequence files, typically this should be on a fast filesystem as it's the most IO intensive from our experience (use either a performance oriented distributed FS like Lustre or GPFS, or a ramdisk).
export RECOUNT_TEMP_HOST=/home/ubuntu/temp/${run_acc}_att0
#may need to change this to real path to the reference indexes (this directory should contain the ref_name passed in e.g. "hg38")
export RECOUNT_REF_HOST=$ref_path

mkdir -p $RECOUNT_TEMP_HOST/input
mkdir -p $RECOUNT_INPUT_HOST
mkdir -p $RECOUNT_OUTPUT_HOST

export RECOUNT_TEMP=/container-mounts/recount/temp 
#expects at least $fp1 to be passed in
if [[ $study == 'local' ]]; then
    #hard link the input FASTQ(s) into input directory
    #THIS ASSUMES input files are *on the same filesystem* as the input directory!
    #this is required for accessing the files in the container
    ln -f $fp1 $RECOUNT_TEMP_HOST/input/
    fp1_fn=$(basename $fp1)
    fp_string="$RECOUNT_TEMP/input/$fp1_fn"
    if [[ ! -z $fp2 ]]; then
        ln -f $fp2 $RECOUNT_TEMP_HOST/input/
        fp2_fn=$(basename $fp2)
        fp_string="$RECOUNT_TEMP/input/$fp1_fn;$RECOUNT_TEMP/input/$fp2_fn"
    fi
    #only one run accession per run of this file
    #If you try to list multiple items in a single accessions.txt file you'll get a mixed run which will fail.
    echo -n "${run_acc},LOCAL_STUDY,${ref_name},local,$fp_string" > ${RECOUNT_INPUT_HOST}/accession.txt
else
    echo -n "${run_acc},${study},${ref_name},sra,${run_acc}" > ${RECOUNT_INPUT_HOST}/accession.txt
fi

export RECOUNT_INPUT=/container-mounts/recount/input
export RECOUNT_OUTPUT=/container-mounts/recount/output
export RECOUNT_REF=/container-mounts/recount/ref

export RECOUNT_CPUS=$num_cpus

export RECOUNT_TEMP_BIG_HOST=/dev/shm/temp_big/${run_acc}_att0
mkdir -p $RECOUNT_TEMP_BIG_HOST
export RECOUNT_TEMP_BIG=/container-mounts/recount/temp_big

sudo docker run -it --env-file pump-env.list -v $RECOUNT_REF_HOST:$RECOUNT_REF -v $RECOUNT_TEMP_BIG_HOST:$RECOUNT_TEMP_BIG -v $RECOUNT_TEMP_HOST:$RECOUNT_TEMP -v $RECOUNT_INPUT_HOST:$RECOUNT_INPUT -v $RECOUNT_OUTPUT_HOST:$RECOUNT_OUTPUT quay.io/benlangmead/recount-rs5 /bin/bash -c "source activate recount && /startup.sh && /workflow.bash"
