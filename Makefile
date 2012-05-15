.SUFFIXES : .o .f90 .f .F90

AORSA2D = xaorsa2d
AORSA1D = xaorsa1d
SRC_DIR = src
OBJ_DIR = obj
MOD_DIR = mod

COMPILER := GNU# GNU, PGI
PARALLEL := 1# 0, 1

# objects
# -------

OBJ_FILES = $(wildcard obj/*.o)

# libraries 
# ---------

BLAS := ${HOME}/code/goto_blas/libgoto2_gnu_4.3.2_64.a -pthread
LAPACK := ${HOME}/code/lapack/lapack-3.1.1/lapack_LINUX.a 
HDF_DIR := ${HOME}/code/hdf/gnu_4.3.2
HDF := -I ${HDF_DIR}/include -L ${HDF_DIR}/lib -lhdf5 -lhdf5_hl
NETCDF_DIR := ${HOME}/code/netcdf/gnu_4.3.2
NETCDF := -I ${NETCDF_DIR}/include -L ${NETCDF_DIR}/lib -lnetcdf -lnetcdff

LIBS := ${HDF} ${NETCDF} ${BLAS} ${LAPACK}
INC_DIR := 
CPP_DIRECTIVES :=

ifeq (${PARALLEL},1)
    CPP_DIRECTIVES += -Dpar
	BLACS = \
		${HOME}/code/blacs/blacs_gnu64/LIB/blacs_MPI-LINUX-0.a \
		${HOME}/code/blacs/blacs_gnu64/LIB/blacsF77init_MPI-LINUX-0.a \
		${HOME}/code/blacs/blacs_gnu64/LIB/blacs_MPI-LINUX-0.a
	SCALAPACK = ${HOME}/code/scalapack/scalapack_gnu64/libscalapack.a
	LIBS := ${SCALAPACK} ${BLACS} ${LIBS}
endif

# set solve precision to double 
# -----------------------------
CPP_DIRECTIVES += -Ddblprec 

# set the coordinate system to an understandable 
# cylindrical ("-DcylProper")  
# ----------------------------------------------
CPP_DIRECTIVES += -DcylProper

# set the z function to use
# either "zFunOriginal" or "zFunHammett"
# --------------------------------------
CPP_DIRECTIVES += -DzFunHammett 

# use papi, set to "-Dusepapi"
# ----------------------------
CPP_DIRECTIVES += -Dusepapi 
PAPI_DIR := /home/dg6/code/papi/gnu_4.3.2
PAPI_INC := -I${PAPI_DIR}/include/
PAPI_LINK := -L${PAPI_DIR}/lib -lpapi
LIBS += ${PAPI_LINK}
INC_DIR += ${PAPI_INC}

# use CUDA
# --------
#LIBS += #${MAGMA} ${CUDA} -lstdc++
#CUDA_DIR = ${HOME}/code/cuda/4.0/cuda
#CUDA = -L ${CUDA_DIR}/lib64 -lcublas -lcudart -lcuda -L /usr/lib64
#MAGMA_DIR = ${HOME}/code/magma/magma_0.2
#MAGMA = -L ${MAGMA_DIR}/lib -lmagma -lmagmablas ${MAGMA_DIR}/lib/libmagma_64.a

# GPTL
# ----
#GPTL_DIR = #${HOME}/code/gptl
#GPTL = #-I ${GPTL_DIR}/include -L ${GPTL_DIR} -lgptl


# caculate sigma as part of the fill (=2) or standalone with file write (=1)
# --------------------------------------------------------------------------
CPP_DIRECTIVES += -D__sigma__=2

# Try removing the U rotation matricies (actually just set to the identity in places)
# and just have the output of the sigma routines be in rtz coords and not in alp,bet,prl.
# This is in an attempt to see how this is related to the noise problem with the poloidal
# field. 
# ---------------------------------------------------------------------------------------
CPP_DIRECTIVES += -D__noU__=0

# debug flags
# -----------

CPP_DIRECTIVES += -D__debugSigma__=0

# Double check that myRow==pr_sp .and. myCol==pc_sp 

CPP_DIRECTIVES += -D__CheckParallelLocation__=0

# compile flags
# -------------

FORMAT := -ffree-line-length-none
BOUNDS := -fbounds-check 
WARN := -Wall
DEBUG := #-pg -g -fbacktrace -fsignaling-nans -ffpe-trap=zero,invalid#,overflow#,underflow
OPTIMIZATION := -O3
DOUBLE := -fdefault-real-8
MOD_LOC := -Jmod

ifeq (${COMPILER},PGI)
    MOD_LOC:= -module mod
    DOUBLE:= -Mr8
    WARN:=
    DEBUG:= -g -traceback -Ktrap=divz,inv,ovf
    OPTIMIZATION:=
    BOUNDS:= -Mbounds
    FORMAT:=
endif



ifeq (${PARALLEL},1)
	F90 = mpif90
else
	F90 = gfortran
endif


# other machines
# --------------

ifeq (${HOME},/global/homes/g/greendl1)
	include Makefile.nersc
endif

ifeq (${HOME},/ccs/home/dg6)
	include Makefile.jaguarpf
endif

ifeq (${HOME},/Users/dg6)
	include Makefile.greendl
endif

F90FLAGS = ${FORMAT} ${WARN} ${DEBUG} ${BOUNDS} ${MOD_LOC} ${OPTIMIZATION}
LINK_FLAGS = 

.PHONY: depend clean

${AORSA2D}: ${SRC_DIR}/aorsa.F90  
	$(F90) ${F90FLAGS} ${SRC_DIR}/aorsa.F90 -o \
			${AORSA2D} \
			$(OBJ_FILES) \
			${GPTL} $(LIBS) \
			${LINK_FLAGS} \
			${CPP_DIRECTIVES} \
			${INC_DIR}

# SRC files

${OBJ_DIR}/%.o: ${SRC_DIR}/%.f90
	${F90} -c ${F90FLAGS} $< -o $@ ${BOUNDS} ${NETCDF} ${CPP_DIRECTIVES} ${INC_DIR}

${OBJ_DIR}/%.o: ${SRC_DIR}/%.F90
	${F90} -c ${F90FLAGS} $< -o $@ ${BOUNDS} ${NETCDF} ${CPP_DIRECTIVES} ${INC_DIR}

${OBJ_DIR}/%.o: ${SRC_DIR}/%.f
	${F90} -c ${F90FLAGS} $< -o $@ ${BOUNDS} ${NETCDF} ${CPP_DIRECTIVES} ${INC_DIR}

${OBJ_DIR}/%.o: ${SRC_DIR}/%.F
	${F90} -c ${F90FLAGS} $< -o $@ ${BOUNDS} ${NETCDF} ${CPP_DIRECTIVES} ${INC_DIR}

${OBJ_DIR}/z_erf.o: ${SRC_DIR}/z_erf.f90
	${F90} -c ${F90FLAGS} $< -o $@ ${BOUNDS} ${INC_DIR} ${DOUBLE}

# Uncomment the following 4 rules for MAGMA implementation
# in addition to two lines in Makefile.deps and adding two 
# trailing underscores in src/solve.f90

#${OBJ_DIR}/solve.o: ${SRC_DIR}/solve.F90
#	${F90} -c ${F90FLAGS} $< -o $@ ${BOUNDS} ${NETCDF} ${CPP_DIRECTIVES} ${INC_DIR} -fno-underscoring
#
#${OBJ_DIR}/get_nb.o: ${MAGMA_DIR}/testing/get_nb.cpp
#	${F90} -c $< -o $@ -fPIC
#
#${OBJ_DIR}/fortran.o: ${CUDA_DIR}/src/fortran.c
#	gcc -c $< -o $@ -I ${CUDA_DIR}/include
#
#${OBJ_DIR}/magma_solve.o: ${SRC_DIR}/magma_solve.cpp 
#	gcc -c -g $< -o $@ -I ${CUDA_DIR}/include -I ${MAGMA_DIR}/include


# Double precision routines
# -------------------------

include Makefile.double

# Dependancies
# ------------

include Makefile.deps

clean:
	rm ${AORSA1D} ${AORSA2D} $(OBJ_DIR)/*.o $(MOD_DIR)/*.mod aorsa.o


