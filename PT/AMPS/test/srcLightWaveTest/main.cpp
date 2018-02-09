/*
 * main.cpp
 *
 *  Created on: Jun 21, 2012
 *      Author: fougere and vtenishe
 */

//$Id$


#include "pic.h"
#include "constants.h"

#include <stdio.h>
#include <stdlib.h>
#include <vector>
#include <string>
#include <list>
#include <math.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <time.h>
#include <iostream>
#include <fstream>
#include <time.h>
#include <algorithm>
#include <sys/time.h>
#include <sys/resource.h>


#include "meshAMRcutcell.h"
#include "cCutBlockSet.h"
#include "meshAMRgeneric.h"

#include "../../srcInterface/LinearSystemCornerNode.h"
#include "linear_solver_wrapper_c.h"

#include "PeriodicBCTest.dfn"

int nVars=3; //number of variables in center associated data
double Background[3]={100.0,-20.0,10.0};


//#define _UNIFORM_MESH_ 1
//#define _NONUNIFORM_MESH_ 2

#ifndef _TEST_MESH_MODE_
#define _TEST_MESH_MODE_ _UNIFORM_MESH_
#endif


double xmin[3]={-2.0,-2.0,-2.0};
double xmax[3]={2.0,2.0,2.0};

int CurrentCenterNodeOffset=-1,NextCenterNodeOffset=-1;
int CurrentCornerNodeOffset=-1,NextCornerNodeOffset=-1;


void SetIC() {
  
    int i,j,k;
    char *offset;
    cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *node;
    double cPi = 3.14159265;
    //    double waveNumber[3]={cPi/2/sqrt(2),cPi/2/sqrt(2),0.0};
    double waveNumber[3]={cPi/2,0.0,0.0}; 
    double x[3];
   
    using namespace PIC::FieldSolver::Electromagnetic::ECSIM;
    int nBreak=0;

    printf("User Set IC called\n");
    for (int nLocalNode=0;nLocalNode<PIC::DomainBlockDecomposition::nLocalBlocks;nLocalNode++) {
      node=PIC::DomainBlockDecomposition::BlockTable[nLocalNode];
      
      if (_PIC_BC__PERIODIC_MODE_==_PIC_BC__PERIODIC_MODE_ON_) {
	bool BoundaryBlock=false;
	
	for (int iface=0;iface<6;iface++) if (node->GetNeibFace(iface,0,0)==NULL) {
	    //the block is at the domain boundary, and thresefor it is a 'ghost' block that is used to impose the periodic boundary conditions
	    BoundaryBlock=true;
	    break;
	  }
	
	if (BoundaryBlock==true) continue;
      }
      

     
      for (k=0;k<_BLOCK_CELLS_Z_;k++) for (j=0;j<_BLOCK_CELLS_Y_;j++) for (i=0;i<_BLOCK_CELLS_X_;i++) {
	    
	    PIC::Mesh::cDataCornerNode *CornerNode= node->block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,j,k));
	    if (CornerNode!=NULL){
	      offset=CornerNode->GetAssociatedDataBufferPointer();
	      
	      x[0]=node->xmin[0]+(i*(node->xmax[0]-node->xmin[0]))/_BLOCK_CELLS_X_;
	      x[1]=node->xmin[1]+(j*(node->xmax[1]-node->xmin[1]))/_BLOCK_CELLS_Y_;
	      x[2]=node->xmin[2]+(k*(node->xmax[2]-node->xmin[2]))/_BLOCK_CELLS_Z_;

	 
	      double E = 10*sin(waveNumber[0]*(x[0]-xmin[0])+waveNumber[1]*(x[1]-xmin[1])+waveNumber[2]*(x[2]-xmin[2]));
	     
	      //1e9 charge in species.input
	      if (_CURRENT_MODE_==_PIC_MODE_OFF_){ 
		/*((double*)(offset+CurrentEOffset))[ExOffsetIndex]=-E/sqrt(2);
		((double*)(offset+CurrentEOffset))[EyOffsetIndex]=E/sqrt(2);
		((double*)(offset+CurrentEOffset))[EzOffsetIndex]=0.0;
		*/
		((double*)(offset+CurrentEOffset))[ExOffsetIndex]=0.0;                                                           
                ((double*)(offset+CurrentEOffset))[EyOffsetIndex]=E; 
		((double*)(offset+CurrentEOffset))[EzOffsetIndex]=E;      
		
	      ((double*)(offset+OffsetE_HalfTimeStep))[ExOffsetIndex]=0.0;
	      ((double*)(offset+OffsetE_HalfTimeStep))[EyOffsetIndex]=0.0;
	      ((double*)(offset+OffsetE_HalfTimeStep))[EzOffsetIndex]=0.0;
	      }else{
		
		((double*)(offset+CurrentEOffset))[ExOffsetIndex]=0.0;
		((double*)(offset+CurrentEOffset))[EyOffsetIndex]=0.0;
		((double*)(offset+CurrentEOffset))[EzOffsetIndex]=0.0;
		
		
		((double*)(offset+OffsetE_HalfTimeStep))[ExOffsetIndex]=0.0;
		((double*)(offset+OffsetE_HalfTimeStep))[EyOffsetIndex]=0.0;
		((double*)(offset+OffsetE_HalfTimeStep))[EzOffsetIndex]=0.0;		

	      }

	    

	    // ((double*)(offset+CurrentCornerNodeOffset))[EzOffsetIndex]=i+j*_BLOCK_CELLS_X_+k*_BLOCK_CELLS_X_*_BLOCK_CELLS_Y_+nLocalNode*_BLOCK_CELLS_X_*_BLOCK_CELLS_Y_*_BLOCK_CELLS_Z_;


	    
	    //((double*)(offset+NextCornerNodeOffset))[EzOffsetIndex]=i+j*_BLOCK_CELLS_X_+k*_BLOCK_CELLS_X_*_BLOCK_CELLS_Y_+nLocalNode*_BLOCK_CELLS_X_*_BLOCK_CELLS_Y_*_BLOCK_CELLS_Z_;
	    }//
	  }//for (k=0;k<_BLOCK_CELLS_Z_+1;k++) for (j=0;j<_BLOCK_CELLS_Y_+1;j++) for (i=0;i<_BLOCK_CELLS_X_+1;i++) 
      for (k=0;k<_BLOCK_CELLS_Z_;k++) for (j=0;j<_BLOCK_CELLS_Y_;j++) for (i=0;i<_BLOCK_CELLS_X_;i++) {
	     
	    PIC::Mesh::cDataCenterNode *CenterNode= node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i,j,k));
	    if (CenterNode!=NULL){
	      offset=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i,j,k))->GetAssociatedDataBufferPointer();

	      x[0]=node->xmin[0]+((i+0.5)*(node->xmax[0]-node->xmin[0]))/_BLOCK_CELLS_X_;
	      x[1]=node->xmin[1]+((j+0.5)*(node->xmax[1]-node->xmin[1]))/_BLOCK_CELLS_Y_;
	      x[2]=node->xmin[2]+((k+0.5)*(node->xmax[2]-node->xmin[2]))/_BLOCK_CELLS_Z_;

	      double B = 10*sin(waveNumber[0]*(x[0]-xmin[0])+waveNumber[1]*(x[1]-xmin[1])+waveNumber[2]*(x[2]-xmin[2]));
	    
	    
	      if (_CURRENT_MODE_==_PIC_MODE_OFF_){
	      
		((double*)(offset+CurrentBOffset))[BxOffsetIndex]=0.0;
		((double*)(offset+CurrentBOffset))[ByOffsetIndex]=B;
		((double*)(offset+CurrentBOffset))[BzOffsetIndex]=-B;
		
		
		((double*)(offset+PrevBOffset))[BxOffsetIndex]=0.0;
		((double*)(offset+PrevBOffset))[ByOffsetIndex]=0.0;
		((double*)(offset+PrevBOffset))[BzOffsetIndex]=0.0;
	      
	      }else{
			      
		((double*)(offset+CurrentBOffset))[BxOffsetIndex]=0.0;
		((double*)(offset+CurrentBOffset))[ByOffsetIndex]=0.0;
		((double*)(offset+CurrentBOffset))[BzOffsetIndex]=0.0;
		
		
		((double*)(offset+PrevBOffset))[BxOffsetIndex]=0.0;
		((double*)(offset+PrevBOffset))[ByOffsetIndex]=0.0;
		((double*)(offset+PrevBOffset))[BzOffsetIndex]=0.0;
		
	      }
	      
	    }// if (CenterNode!=NULL)
	  }//for (k=0;k<_BLOCK_CELLS_Z_;k++) for (j=0;j<_BLOCK_CELLS_Y_;j++) for (i=0;i<_BLOCK_CELLS_X_;i++) 
    }
   
    switch (_PIC_BC__PERIODIC_MODE_) {
    case _PIC_BC__PERIODIC_MODE_OFF_:
      PIC::Mesh::mesh.ParallelBlockDataExchange();
      break;
      
    case _PIC_BC__PERIODIC_MODE_ON_:
      PIC::BC::ExternalBoundary::Periodic::UpdateData();
      break;
    }
}


double localTimeStep(int spec,cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *startNode) {
    double CellSize;
    double CharacteristicSpeed;
    double dt;


    CellSize=startNode->GetCharacteristicCellSize();
    //return 0.3*CellSize/CharacteristicSpeed;

    //return 0.05;
    return 0.2;
}


double BulletLocalResolution(double *x) {                                                                                           
  double dist = xmax[0]-xmin[0];

#if _TEST_MESH_MODE_==_UNIFORM_MESH_  
  double res = 3;
#endif

#if _TEST_MESH_MODE_==_NONUNIFORM_MESH_
  double highRes = dist/32.0, lowRes= dist/2.0;     
  double res =(5-1)/dist*(x[0]-xmin[0])+1;  
#endif

  res=dist/pow(2,res);
  
  return res;
}
                       

int main(int argc,char **argv) {
  PIC::InitMPI();
  PIC::Init_BeforeParser();


  int RelativeOffset=0;
  
#if _TEST_MESH_MODE_==_NONUNIFORM_MESH_
  printf("non-uniform mesh!\n");
#endif
#if _TEST_MESH_MODE_==_UNIFORM_MESH_
  printf("uniform mesh!\n");
#endif


#if _CURRENT_MODE_==_PIC_MODE_ON_
  printf("current on!\n");
#endif
#if _CURRENT_MODE_==_PIC_MODE_OFF_
  printf("current mode off!\n");
#endif

  PIC::FieldSolver::Electromagnetic::ECSIM::SetIC=SetIC;

  //seed the random number generator
  rnd_seed(100);

  //generate mesh or read from file
  char mesh[_MAX_STRING_LENGTH_PIC_]="none";  ///"amr.sig=0xd7058cc2a680a3a2.mesh.bin";
  sprintf(mesh,"amr.sig=%s.mesh.bin","test_mesh");

  PIC::Mesh::mesh.AllowBlockAllocation=false;
  if(_PIC_BC__PERIODIC_MODE_== _PIC_BC__PERIODIC_MODE_ON_){
  PIC::BC::ExternalBoundary::Periodic::Init(xmin,xmax,BulletLocalResolution);
  }else{
    PIC::Mesh::mesh.init(xmin,xmax,BulletLocalResolution);
  }
  PIC::Mesh::mesh.memoryAllocationReport();

  //generate mesh or read from file
  bool NewMeshGeneratedFlag=false;

  char fullname[STRING_LENGTH];
  sprintf(fullname,"%s/%s",PIC::UserModelInputDataPath,mesh);

  FILE *fmesh=NULL;

  fmesh=fopen(fullname,"r");

  if (fmesh!=NULL) {
    fclose(fmesh);
    PIC::Mesh::mesh.readMeshFile(fullname);
  }
  else {
    NewMeshGeneratedFlag=true;

    if (PIC::Mesh::mesh.ThisThread==0) {
       PIC::Mesh::mesh.buildMesh();
       PIC::Mesh::mesh.saveMeshFile("mesh.msh");
       MPI_Barrier(MPI_GLOBAL_COMMUNICATOR);
    }
    else {
       MPI_Barrier(MPI_GLOBAL_COMMUNICATOR);
       PIC::Mesh::mesh.readMeshFile("mesh.msh");
    }
  }


  //if the new mesh was generated => rename created mesh.msh into amr.sig=0x%lx.mesh.bin
  if (NewMeshGeneratedFlag==true) {
    unsigned long MeshSignature=PIC::Mesh::mesh.getMeshSignature();

    if (PIC::Mesh::mesh.ThisThread==0) {
      char command[300];

      sprintf(command,"mv mesh.msh amr.sig=0x%lx.mesh.bin",MeshSignature);
      system(command);
    }
  }

  MPI_Barrier(MPI_GLOBAL_COMMUNICATOR);
  

  //PIC::Mesh::initCellSamplingDataBuffer();

  PIC::Mesh::mesh.CreateNewParallelDistributionLists();

  PIC::Mesh::mesh.AllowBlockAllocation=true;
  PIC::Mesh::mesh.AllocateTreeBlocks();
  PIC::Mesh::mesh.InitCellMeasure();

  PIC::Init_AfterParser();
  PIC::Mover::Init();

  //set up the time step
  PIC::ParticleWeightTimeStep::LocalTimeStep=localTimeStep;
  PIC::ParticleWeightTimeStep::initTimeStep();

  if (PIC::ThisThread==0) printf("test1\n");
  PIC::Mesh::mesh.outputMeshTECPLOT("mesh_test.dat");
  
  if(_PIC_BC__PERIODIC_MODE_== _PIC_BC__PERIODIC_MODE_ON_){
  PIC::BC::ExternalBoundary::Periodic::InitBlockPairTable();
  }
  //-387.99e2
  double v[10][3]={{-1.0, 0.0, 0.0},{1.0,0.0, 0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0.0},{0.0,0.0,0},{0.0,0.0,0.0},{1,1,1},{0.8,0.8,-1}};
  double xparticle[10][3]={{0.125,0.125,0.125},{0.125,0.125,0.125},{1,1,-1},{-1,1,-1},{-1,-1,1},{1,-1,1},{1,1,1},{-1,1,1},{2.9,0.9,2.9},{2.9,0.9,2.9}};
  int s,i,j,k;
  int species[10]={0,1,0,1,0,1,0,1,0,1};
  
  int parSize;
  if (_CURRENT_MODE_==_PIC_MODE_OFF_){
    parSize=0;
  }else{
    parSize=2;
  }


  cTreeNodeAMR<PIC::Mesh::cDataBlockAMR>* newNode;
  long int newParticle;

  if (PIC::ThisThread==0) printf("test2\n");
 
  // PIC::ParticleWeightTimeStep::initParticleWeight_ConstantWeight(0);
  //PIC::ParticleWeightTimeStep::initParticleWeight_ConstantWeight(1);
  
  PIC::ParticleWeightTimeStep::SetGlobalParticleWeight(0,1.0);
  PIC::ParticleWeightTimeStep::SetGlobalParticleWeight(1,1.0);

  PIC::DomainBlockDecomposition::UpdateBlockTable();

  //solve the transport equation
  //set the initial conditions for the transport equation
  //  TransportEquation::SetIC(3);
 

  switch (_PIC_BC__PERIODIC_MODE_) {
  case _PIC_BC__PERIODIC_MODE_OFF_:
      PIC::Mesh::mesh.ParallelBlockDataExchange();
      break;
      
  case _PIC_BC__PERIODIC_MODE_ON_:
    PIC::BC::ExternalBoundary::Periodic::UpdateData();
      break;
  }
  //PIC::FieldSolver::Init(); 
   PIC::FieldSolver::Electromagnetic::ECSIM::Init_IC();
 

  switch (_PIC_BC__PERIODIC_MODE_) {
  case _PIC_BC__PERIODIC_MODE_OFF_:
      PIC::Mesh::mesh.ParallelBlockDataExchange();
      break;
      
  case _PIC_BC__PERIODIC_MODE_ON_:
    PIC::BC::ExternalBoundary::Periodic::UpdateData();
      break;
  }
  PIC::Mesh::mesh.outputMeshDataTECPLOT("ic.dat",0);
  

  int  totalIter;
  if (_CURRENT_MODE_==_PIC_MODE_OFF_){
    totalIter = 4/PIC::FieldSolver::Electromagnetic::ECSIM::cDt;
  }else{
    totalIter = 3;
  }
 
  // countNumbers();

  
  for (int iPar=0;iPar<parSize; iPar++ ){
    newNode=PIC::Mesh::mesh.findTreeNode(xparticle[iPar]);
    
    if (newNode->Thread==PIC::ThisThread) {
      PIC::Mesh::mesh.fingCellIndex(xparticle[iPar],i,j,k,newNode);
      
      newParticle=PIC::ParticleBuffer::GetNewParticle(newNode->block->FirstCellParticleTable[i+_BLOCK_CELLS_X_*(j+_BLOCK_CELLS_Y_*k)]);
      
      PIC::ParticleBuffer::SetV(v[iPar],newParticle);
      PIC::ParticleBuffer::SetX(xparticle[iPar],newParticle);
      PIC::ParticleBuffer::SetI(species[iPar],newParticle);
    }
  }
 

    switch (_PIC_BC__PERIODIC_MODE_) {
  case _PIC_BC__PERIODIC_MODE_OFF_:
      PIC::Mesh::mesh.ParallelBlockDataExchange();
      break;
      
  case _PIC_BC__PERIODIC_MODE_ON_:
    PIC::BC::ExternalBoundary::Periodic::UpdateData();
      break;
  }

  for (int niter=0;niter<totalIter;niter++) {
    
    //PIC::Mesh::mesh.outputMeshDataTECPLOT("1.dat",0);
    
    //TransportEquation::TimeStep();
  
    PIC::TimeStep();
    //PIC::FieldSolver::Electromagnetic::ECSIM::TimeStep();

    //PIC::Mesh::mesh.outputMeshDataTECPLOT("2.dat",0);


    switch (_PIC_BC__PERIODIC_MODE_) {
    case _PIC_BC__PERIODIC_MODE_OFF_:
      PIC::Mesh::mesh.ParallelBlockDataExchange();
      break;

    case _PIC_BC__PERIODIC_MODE_ON_:
      PIC::BC::ExternalBoundary::Periodic::UpdateData();
      break;
    }


    char fname[100];
    sprintf(fname,"LightWave.out=%i.dat",niter);
    // if (niter%10==0) PIC::Mesh::mesh.outputMeshDataTECPLOT(fname,0);
  
    PIC::Mesh::mesh.outputMeshDataTECPLOT(fname,0);
  }


  MPI_Finalize();
  cout << "End of the run" << endl;

  return EXIT_SUCCESS;
}