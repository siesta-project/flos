"""
Created on Fri Sep 28 15:55:30 2018

@author: arsalan
"""
#==========================================================================
# Script for Energy vs Basis calculation 
# Written by Arsalan Akhtar 
# ICN2 31-August-2017 v-0.1
# ICN2 1-October-2018 v-0.2
# ICN2 2-October-2018 v-0.3
# ICN2 2-October-2018 v-0.4
#==========================================================================
# Libray imports
import os, shutil
import matplotlib.pyplot as plt
import numpy as np
#==========================================================================
GNUBANDSBIN='/home/ICN2/aakhtar/Softwares/siesta-4.1-b3/Util/Bands/gnubands'
fermi_lw=1  # energy fermi line thickness parameters 
#x_plot_min=
#x_plot_max=

print ("*******************************************************************")
print ("This is a test script written by A.Akhtar for Ploting Band Basis")
print ("Email:arsalan.akhtar@icn2.cat")
print ("*******************************************************************")
Energy=[]
for line in open('input.fdf'):
    if 'SystemLabel' in line:
        Energy.append((line.split(" ",1)[-1])) 
file_index_name=str(Energy[0])
#print file_index_name.strip()+'.bands'
gnuband_input=file_index_name.strip()+'.bands'
#-----------------------------------------------------------------------------
#Reading fermi energy From *.band Files
#-----------------------------------------------------------------------------
#%%
efermi=[]
bzpt=[]
minE=[]
maxE=[]
fp = open(gnuband_input)
for i, line in enumerate(fp):
    if i==0:
        efermi=line.split()
    if i==1:
        bzpt=line.split()
    if i == 2:
        #print (line)
      tmp=line.split()  
      minE.append(tmp[0])
      maxE.append(tmp[1])
print ("The Fermi Energy is ( in eV ) : " +str(efermi[0]))
#-----------------------------------------------------------------------------
#Reading fermi energy From *.band Files
#-----------------------------------------------------------------------------

#%%
#-----------------------------------------------------------------------------
#Reading high Symmetry Lines from *.band Files
#-----------------------------------------------------------------------------
fbzpoint=[]
fbzname=[]
print ("The high symmetry points of structure are : \n")
for sympoint in open(gnuband_input):
    if "'" in sympoint:
        print (sympoint)
        i_sympoint=sympoint.split()
        print (i_sympoint)
        if len(i_sympoint):
            fbzpoint.append(float(i_sympoint[0]))
            fbzname.append(i_sympoint[1].replace("'",''))
#%%
if not os.path.exists('Bandstructure'):os.mkdir("Bandstructure") and os.chdir('Bandstructure')

print ("===================================================================")
print (" Starting Band Calculation                                         ")
os.system(GNUBANDSBIN+" -e "+ str(int(float(minE[0]))-1)+" -E "+str(int(float(maxE[0]))+1)+' < ' + gnuband_input+'  > '+'./Bandstructure/bandoutput') 
print (" The Band file for plotting is in 'band.output'                    ")
print ("===================================================================")
os.chdir("./Bandstructure")
#%%
#--------------------------------------------------------------------------
#                           Read input data 
#--------------------------------------------------------------------------
#%%
#%matplotlib qt
tkpoint=[]
energy_up=[]
kpoint_up=[]
energy_down=[]
kpoint_down=[]
nbnd=1
for line in open('bandoutput'):
    if '#' not in line:
        i_line=line.split()
        if len(i_line)>0:
            tkpoint.append(float(i_line[0]))
            if i_line[2]=='1':
                #print(i_line)
                energy_up.append(float(i_line[1]))
                kpoint_up.append(float(i_line[0]))
            if i_line[2]=="2":
                #print(i_line)
                energy_down.append(float(i_line[1]))
                kpoint_down.append(float(i_line[0]))
    if "# Nbands, Nspin, Nk =" in line:
        j_line=line.split()
        print ("Number of Bands = "+ str(j_line[5]))
        print ("Number of Spins = "+ str(j_line[6]))
        print ("Number of kpoints = "+ str(j_line[7]))
        print ("Total = "+ str(int(j_line[5])*int(j_line[6])*int(j_line[7])))
numbands=j_line[5] 
Nspins=j_line[6]
Nkpoints=j_line[7]       
#%%
#-----------------------------------------------------------------------------
#Plotting Spin Up
#-----------------------------------------------------------------------------
nkpoint_up=(int(len(energy_up))/int(numbands))
for i in range(int(numbands)):
    x1 = kpoint_up[int(nkpoint_up)*i:(i+1)*int(nkpoint_up)]
    y1 = energy_up[int(nkpoint_up)*i:(i+1)*int(nkpoint_up)]
    #plt.subplot(2, 1, 1)
    #plot(x1,y1)
    plt.plot(x1,y1)
plt.title("Spin Up Bandstructure")   
#%%
#-----------------------------------------------------------------------------
# x_final is the paramiter for x axis plotting
x_final=fbzpoint[2]
plt.xlim(fbzpoint[0],x_final)
plt.ylim(float(efermi[0])-5,float(efermi[0])+5)
plt.axhline(y=float(efermi[0]),  linewidth=fermi_lw, color='m')
#plt.yticks([float(efermi[0])],"Fermi")
plt.xlabel('First Brillouin Zone')
plt.ylabel('Energy [eV]')
xt=[]

fbzname_plot=[]
for pt in range(len(fbzpoint)):
    print (str(fbzpoint[pt])+"--->"+str(fbzname[pt]))
    fbzname_plot.append(fbzpoint[pt])
    if fbzpoint[pt]==x_final:
        break
for pointname in fbzname_plot:#
    xt.append(pointname)   
plt.xticks(xt,fbzname)
plt.savefig('bandstructure-up.pdf')
plt.close()
#%%
#-----------------------------------------------------------------------------
#Plotting Spin Down
#-----------------------------------------------------------------------------
nkpoint_down=(int(len(energy_down))/int(numbands))
for i in range(int(numbands)):
    x2 = kpoint_down[int(nkpoint_down)*i:(i+1)*int(nkpoint_down)]
    y2 = energy_down[int(nkpoint_down)*i:(i+1)*int(nkpoint_down)]
    plt.plot(x2,y2)
plt.title("Spin Down Bandstructure")
#-----------------------------------------------------------------------------
# x_final is the paramiter for x axis plotting
x_final=fbzpoint[2]
plt.xlim(fbzpoint[0],x_final)
plt.ylim(float(efermi[0])-5,float(efermi[0])+5)
plt.axhline(y=float(efermi[0]), linewidth=fermi_lw, color='m')
#plt.yticks([float(efermi[0])],"Fermi")
plt.xlabel('First Brillouin Zone')
plt.ylabel('Energy [eV]')
xt=[]
fbzname_plot=[]
for pt in range(len(fbzpoint)):
    print (str(fbzpoint[pt])+"--->"+str(fbzname[pt]))
    fbzname_plot.append(fbzpoint[pt])
    if fbzpoint[pt]==x_final:
        break
for pointname in fbzname_plot:#
    xt.append(pointname)   
plt.xticks(xt,fbzname)
plt.savefig('bandstructure-down.pdf')

#os.chdir("../")
#%%
