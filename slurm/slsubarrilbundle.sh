#!/bin/bash

# Create and submit Ilastik jobs to SLURM queue
# Jobs are generated based on image (tif or tiff) files in a provided path.
# By default, a single job array will consist of the number of tasks equal to the number of images in the indir path.
# An option -n can bundle multiple images into a single array task.

usage="Error: insufficient arguments!
This script submits to SLURM queue image processing defined in Ilastik project file. One SLURM task is created for every tif image in a provided path.

Usage: $(basename "$0") -options Ilastik-project-file

Possible options:
        -h | --help             Show this help text.
        -t | --test             Test mode: creates all intermediate files without submitting to a queue.
	-i | --indir		Directory with input tif images to process; default current directory.
        -o | --outdir           Directory with output tif images with probabilities; defalut TIFFs_prob.
	-s | --spatt		Search pattern for image files; default \"*.tif\".		
	-c | --reqcpu		Required number of cores; default 8.
	-m | --reqmem           Required memory per cpu; default 12GB.
        -e | --reqtime          Required time per task; default 6h.
        -p | --partition        Name of the slurm queue partition; default all.
	-n | --impertask	Number of images in as single task of a job array, default 1.
	-b | --binpath 		Path to Ilastik binary; default /opt/local/bin/run_ilastik.sh"

E_BADARGS=85

if [ ! -n "$1" ]
then
  echo "$usage"
  exit $E_BADARGS
fi

## Definitions
# User home directory
USERHOMEDIR=`eval echo "~$USER"`

# Path to Ilastik binary
BINPATH=/opt/local/bin/run_ilastik.sh

# Directory with images to process
INDIR=.

# Directory to store output: images with probabilities
OUTDIR=TIFFs_prob

# Search pattern for input images
SPATT=*.tif

# Required number of cores
REQCPU=8

# Required memory per task; default 4GB
REQMEM=4096

# Required time per task; default 6 hours
REQTIME=6:00:00

# Name of the slurm partition to submit the job
SLPART=all

# Number of images in as single task of a job array, default 1
NIMPERTASK=1

# Test mode switch
TST=0

# Name of SLURM partition
SLPART=all

# Directory with SLURM output
SLOUT=slurm.out
mkdir -p $SLOUT

# Name of the file with the image list
FIMLIST=imagelist.txt

## Read arguments
TEMP=`getopt -o hti:o:s:c:m:e:p:n:b: --long help,test,indir:,outdir:,spatt:,reqcpu:,reqmem:,reqtime:,partition:,impertask:,binpath: -n 'runiljob.sh' -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
# Tutorial at:
# http://www.bahmanm.com/blogs/command-line-options-how-to-parse-in-bash-using-getopt

while true ; do
        case "$1" in
        -t|--test) TST=1 ; shift ;;
        -h|--help) echo "$usage"; exit ;;
        -i|--indir)
            case "$2" in
                "") shift 2 ;;
                *) INDIR=$2 ; shift 2 ;;
            esac ;;
        -o|--outdir)
            case "$2" in
                "") shift 2 ;;
                *) OUTDIR=$2 ; shift 2 ;;
            esac ;;
        -s|--spatt)
            case "$2" in
                "") shift 2 ;;
                *) SPATT=$2 ; shift 2 ;;
            esac ;;
        -c|--reqcpu)
            case "$2" in
                "") shift 2 ;;
                *) REQCPU=$2 ; shift 2 ;;
            esac ;;
        -m|--reqmem)
            case "$2" in
                "") shift 2 ;;
                *) REQMEM=$2 ; shift 2 ;;
            esac ;;
        -e|--reqtime)
            case "$2" in
                "") shift 2 ;;
                *) REQTIME=$2 ; shift 2 ;;
            esac ;;
        -n|--impertask)
            case "$2" in
                "") shift 2 ;;
                *) NIMPERTASK=$2 ; shift 2 ;;
            esac ;;
        -p|--partition)
                case "$2" in
                        "") shitf 2 ;;
                        *) SLPART=$2 ; shift 2 ;;
                esac ;;
        -b|--binpath)
                case "$2" in
                        "") shitf 2 ;;
                        *) BINPATH=$2 ; shift 2 ;;
                esac ;;
        --) shift ; break ;;
     *) echo "Internal error!" ; exit 1 ;;
    esac
done

if [ ! -n "$1" ]
then
	  echo "$usage"
	    exit $E_BADARGS
    fi

## Submit to SLURM queue

# create directory for output images with probabilities
mkdir -p $OUTDIR

# Parameters of the analysis
echo ""
echo "Number of cores per task = $REQCPU"
echo "Memory per task = $REQMEM MB"
echo "Required time for the job = $REQTIME (h:m:s)"
echo ""

# Get the number of files/tasks
echo Looking for "$SPATT" files in $INDIR folder
echo ""

# Create a temp file with the list of images in the INDIR
find ${INDIR} -name "${SPATT}" -type f -print > ${FIMLIST}.tmp

# Relist the images such that multiple images can be bundled in a single array task.
# It means that a single column file list is rearranged to multiple columns, 
# where the number of column corresponds to the number of images per task

awk -v myvar="${NIMPERTASK}" '{printf("%s ", $0); if (NR%myvar == 0) print "";} END{if (NR%myvar > 0) print ""}' ${FIMLIST}.tmp > ${FIMLIST}

NIM=`cat ${FIMLIST}.tmp | wc -l`
NTASKS=`cat ${FIMLIST} | wc -l`
echo "Number of images = $NIM"
echo "Number of images per task = $NIMPERTASK"
echo "Number of tasks in SLURM array = $NTASKS"

rm ${FIMLIST}.tmp

# Create a script that will be executed by sbatch
FARRAY=arrayjobs.sh

echo "#!/bin/bash" > $FARRAY

# Setting params for Slurm
echo "#SBATCH --job-name=ilastik" >> $FARRAY
echo "#SBATCH --array=1-$NTASKS" >> $FARRAY
echo "#SBATCH --cpus-per-task=$REQCPU" >> $FARRAY
echo "#SBATCH --mem=$REQMEM" >> $FARRAY
echo "#SBATCH --time=$REQTIME" >> $FARRAY
echo "#SBATCH --partition=$SLPART" >> $FARRAY
echo "#SBATCH --output=$SLOUT/slurm-%A_%a.out" >> $FARRAY
echo "" >> $FARRAY

# Setting params for Ilastik
#echo "LAZYFLOW_THREADS=$REQCPU" >> $FARRAY
#echo "LAZYFLOW_TOTAL_RAM_MB=$REQMEM" >> $FARRAY
#echo "" >> $FARRAY

# get the file name to process: list directory and take n-th element given by SLURM_ARRAY_TASK_ID
echo "arrayfile=\`cat ${FIMLIST} | awk -v line=\$SLURM_ARRAY_TASK_ID '{if (NR == line) print \$0}' \`" >> $FARRAY

# run Ilastik
echo "$BINPATH 	--headless \\
		--readonly=1 \\
		--project $1 \\
		--output_format=\"multipage tiff\" \\
		--output_filename_format=$OUTDIR/{nickname}.tiff \\
		--export_dtype=uint16 \\
		--output_axis_order=tcyx \\
		--pipeline_result_drange=\"(0.0,1.0)\" \\
		--export_drange=\"(0,65535)\" \\
		--export_source=\"Probabilities\" \\
		\$arrayfile" >> $FARRAY


## Submit jobs to a queue
if [ $TST -eq 1 ]; then
	echo "Test mode ON, jobs were not submitted!"
else
	echo "Submitting jobs..."
	sbatch $FARRAY
fi
