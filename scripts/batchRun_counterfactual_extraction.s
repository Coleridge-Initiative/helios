#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=24:00:00
#SBATCH --mem=50GB
#SBATCH --job-name=counterfactual_extraction
#SBATCH --mail-type=END
#SBATCH --mail-user=nj995@nyu.edu
#SBATCH --output=slurm_%j.out

module purge
module load python3/intel/3.6.3

jupyter nbconvert --inplace --ExecutePreprocessor.timeout=-1 --execute counterfactual_extraction.ipynb