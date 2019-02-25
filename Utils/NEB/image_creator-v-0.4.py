# ==========================================================================
# Script for PDOS calculation 
# Written by Arsalan Akhtar <arsalan.akhtar@icn2.cat>
# ICN2 26-September-2018-v-0.1
# ICN2 04-February-2019-v-0.3 using ASE idpp path included to the script
# ICN2 25-February-2019-v-0.4 Parameters Added by Pol Febrer <pfebrer96@gmail.com>
# ==========================================================================
# Libray imports

from ase import Atoms
from ase.neb import NEB
import os, shutil, sys
from linecache import getline
import numpy as np
import argparse

#==========================================================================
# ----------------------USER Define parameters-------------------------
#==========================================================================

#Parse all the arguments that we need
parser = argparse.ArgumentParser()
parser.add_argument('-d', "--directory", type=str, default=".",
                    help='Directory where the fdf files are located, default is the current directory')
parser.add_argument('-n', "--nimages", type=int, default=5,
                    help='Number of images that must be generated between the two states, default is 5')
parser.add_argument('-if', "--initialfile", type=str, default="initial",
                    help='Name of the initial structure file (without extension), default is "initial"')
parser.add_argument('-ff', "--finalfile", type=str, default="final",
                    help='Name of the final structure file (without extension), default is "final"')
parser.add_argument('-m', "--method", type=str, default="li",
                    help='Interpolation method to generate the images, default is linear interpolation (li), other options are: Image Dependent Pair Potential (idpp)')
args = parser.parse_args()

#Get the working directory
wdir = args.directory

#Get the arguments given (or the default ones)
NAME_OF_INITIAL_STRUCTURE_FILE = f"{wdir}/{args.initialfile}.fdf"
NAME_OF_FINAL_STRUCTURE_FILE = f"{wdir}/{args.finalfile}.fdf"
NUMBER_OF_IMAGES = args.nimages
Interpolation_method = args.method

#==========================================================================
print ("*******************************************************************")
print ("This is script written by A.Akhtar for Generating IMAGES for NEB-LUA program")
print (f"Number of Images ={NUMBER_OF_IMAGES}")

if Interpolation_method == "li":
    print ("Linear Interpolation Method")
else:
    print ("Image Dependent Pair Potential Method")

print ("Email:arsalan.akhtar@icn2.cat")
print ("*******************************************************************")

# =================================================
# Function to read information from the .fdf files
# =================================================

def getInfoFromFdf(filename, labelOfFile = ""):

    chemSpec = []
    relax_info=[]

    listenForSpecies = False
    listenForCoords = False

    for line in open(filename):

        #Remove comments
        line = line.split("#")[0]
        #Get the line in lowercase
        lcLine = line.lower()
        #Split the line
        splitted = line.split()

        if 'systemlabel' in lcLine:
            system_Label = splitted[-1]
        
        elif 'numberofspecies' in lcLine:
            num_species = int(splitted[-1])
        
        elif 'numberofatoms' in lcLine:
            number_of_atoms = int(splitted[-1])
        
        elif "chemicalspecieslabel" in lcLine:
            listenForSpecies = not listenForSpecies
        
        elif listenForSpecies:
            #Save atomic number and species (split by "." just in case there are suffixes, e.g. C.pbr)
            chemSpec.append([int(splitted[1]),splitted[2].split(".")[0]])

        elif "atomiccoordinatesandatomicspecies" in lcLine:
            listenForCoords = not listenForCoords
        
        elif listenForCoords:
            coords = [float(coord) for coord in splitted[:3]]
            species = int(splitted[3]) #This is the index of the species, the name can be found with the help of chemSpec
            relax_info.append([coords,species])
    
    print ("(1) System label is : " + system_Label)
    print ("(2) Number of Species are : " + str(num_species))
    print ("(3) Total Number of Atoms are : " + str(number_of_atoms))

    #Convert the indexes saved in the relax_info to species names
    relax_info = np.array(relax_info)
    relax_info[:,1] = [chemSpec[specNum-1][1] for specNum in relax_info[:,1]]

    if len(relax_info) > 0:
        print (f"{labelOfFile.upper()} COORDINATES READ\n")
    else:
        print(f"UNABLE TO READ {labelOfFile.upper()} COORDINATES\n")

    return [system_Label, num_species, number_of_atoms, np.array(chemSpec), relax_info]

# ==================================================================================
# Opening NAME_OF_FINAL_STRUCTURE_FILE finding label, species and relaxed structure
# ==================================================================================

print("READING INITIAL FILE...")

[i_system_Label, i_num_species, 
i_number_of_atoms, i_chemSpec, i_relax_info] = getInfoFromFdf(NAME_OF_INITIAL_STRUCTURE_FILE,"initial")


# ==================================================================================
# Opening NAME_OF_FINAL_STRUCTURE_FILE finding label, species and relaxed structure
# ==================================================================================

print("READING FINAL FILE...")

[f_system_Label, f_num_species, 
f_number_of_atoms, f_chemSpec, f_relax_info] = getInfoFromFdf(NAME_OF_FINAL_STRUCTURE_FILE, "final")

# ================================
# Defining the structures for ase
# ================================

#Build the strings that Atoms() needs with the names of the species concatenated (e.g "CCHCCCHO")
specStrings = ["".join(i_relax_info[:,1]), "".join(f_relax_info[:,1])]

#And then generate the initial and final images 
initial = Atoms(specStrings[0], positions = list(i_relax_info[:,0]))
final = Atoms(specStrings[1], positions = list(f_relax_info[:,0]))

# ====================================================
# Creating a dummy path that ase needs to interpolate
# ====================================================

images = [initial]

for i in range(NUMBER_OF_IMAGES):
    images.append(initial.copy())

images.append(final)

# ======================================
# Interpolating the intermediate images
# ======================================

neb = NEB(images)
neb.interpolate(None if Interpolation_method == "li" else Interpolation_method)

# ======================================
# Writing the images to .xyz files
# ======================================

filename_anim = f"images_{Interpolation_method}_Animation.xyz"

with open( f"{wdir}/{filename_anim}" , 'w') as f2:

    for i, image in enumerate(images):
        
        filename = f"images_{Interpolation_method}{i}.xyz"

        with open( f"{wdir}/{filename}" ,'w') as f1:

            f1.write(f"{i_number_of_atoms}\n")
            f1.write(f"Image_{i}\n")

            for n in range(i_number_of_atoms):

                species = image.get_chemical_symbols()[n]
                coords = "\t".join([ f"{coord:.8f}" for coord in image.get_positions()[n] ])

                f1.write( f"{species}\t{coords}\n" )
        
        with open( f"{wdir}/{filename}" , "r") as f1:

            f2.write(f1.read())



    
    
    

