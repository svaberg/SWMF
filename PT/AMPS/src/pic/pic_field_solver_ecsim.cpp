
//$Id$
//the field solver routines

/*
 * pic_field_solver_ecsim.cpp
 *
 *  Created on: Jan 18, 2018
 *      Author: vtenishe
 */

#include "pic.h"
//#include "LinearSystemCornerNode.h"
//#include "linear_solver_wrapper_c.h"

//using namespace PIC::FieldSolver::Electromagnetic::ECSIM;


PIC::FieldSolver::Electromagnetic::ECSIM::fSetIC PIC::FieldSolver::Electromagnetic::ECSIM::SetIC=PIC::FieldSolver::Electromagnetic::ECSIM::SetIC_default;

cLinearSystemCornerNode<PIC::Mesh::cDataCornerNode,3,81,82,16,1,1> PIC::FieldSolver::Electromagnetic::ECSIM::Solver;

int PIC::FieldSolver::Electromagnetic::ECSIM::CurrentEOffset=-1;
int PIC::FieldSolver::Electromagnetic::ECSIM::OffsetE_HalfTimeStep=-1;
int PIC::FieldSolver::Electromagnetic::ECSIM::CurrentBOffset=-1;
int PIC::FieldSolver::Electromagnetic::ECSIM::PrevBOffset=-1;

int PIC::FieldSolver::Electromagnetic::ECSIM::ExOffsetIndex=0;
int PIC::FieldSolver::Electromagnetic::ECSIM::EyOffsetIndex=1;
int PIC::FieldSolver::Electromagnetic::ECSIM::EzOffsetIndex=2;
int PIC::FieldSolver::Electromagnetic::ECSIM::JxOffsetIndex;
int PIC::FieldSolver::Electromagnetic::ECSIM::JyOffsetIndex;
int PIC::FieldSolver::Electromagnetic::ECSIM::JzOffsetIndex;
int PIC::FieldSolver::Electromagnetic::ECSIM::BxOffsetIndex=0;
int PIC::FieldSolver::Electromagnetic::ECSIM::ByOffsetIndex=1;
int PIC::FieldSolver::Electromagnetic::ECSIM::BzOffsetIndex=2;
int PIC::FieldSolver::Electromagnetic::ECSIM::MassMatrixOffsetIndex;

double dtTotal = 0.0;
double PIC::FieldSolver::Electromagnetic::ECSIM::cDt=0.0;
double PIC::FieldSolver::Electromagnetic::ECSIM::theta =0.5;
double PIC::FieldSolver::Electromagnetic::ECSIM::LightSpeed =1;

double TotalParticleEnergy=0.0;
double TotalWaveEnergy=0.0;

double E_SI2cgs = 1e-4/3;
double B_SI2cgs = 1e4;
double epsilon0=8.85418782e-12;
double mu0=1.25663706e-6;

/*
double E_SI2cgs = 1;
double B_SI2cgs = 1;
*/
bool IsInit=false;
//The global initialization procedure
void PIC::FieldSolver::Init() {
  if (IsInit) exit(__LINE__,__FILE__,"Error: The field solver already initialized");
  switch (_PIC_FIELD_SOLVER_MODE_) {
  case _PIC_FIELD_SOLVER_MODE__ELECTROMAGNETIC__ECSIM_:
    PIC::FieldSolver::Electromagnetic::ECSIM::Init();
    break;
  default:
    exit(__LINE__,__FILE__,"Error: The field solver Init() has been called with an unknown _PIC_FIELD_SOLVER_MODE_ value");
  }
  IsInit = true;
}

//Field Solver of IPIC3D
void PIC::FieldSolver::Electromagnetic::ECSIM::Init() {
  //init the electric and magnetic field offsets
  //Magnetic field is in the center nodes
  //Electric field is in the corner nodes
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;    

  if (PIC::CPLR::DATAFILE::Offset::MagneticField.active==true) {
    exit(__LINE__,__FILE__,"Error: reinitialization of the magnetic field offset");
  }
  else {
    PIC::CPLR::DATAFILE::Offset::MagneticField.active=true;
    PIC::CPLR::DATAFILE::Offset::MagneticField.RelativeOffset=PIC::Mesh::cDataCenterNode::totalAssociatedDataLength;   
    PIC::Mesh::cDataCenterNode::totalAssociatedDataLength+=2*PIC::CPLR::DATAFILE::Offset::MagneticField.nVars*sizeof(double);
    CurrentBOffset =0;
    PrevBOffset = 3*sizeof(double);
  }

  if (PIC::CPLR::DATAFILE::Offset::ElectricField.active==true) {
    exit(__LINE__,__FILE__,"Error: reinitialization of the electric field offset");
  }
  else {
    PIC::CPLR::DATAFILE::Offset::ElectricField.active=true;
    PIC::CPLR::DATAFILE::Offset::ElectricField.RelativeOffset=PIC::Mesh::cDataCornerNode::totalAssociatedDataLength;
    CurrentEOffset=0;
    PIC::Mesh::cDataCornerNode::totalAssociatedDataLength+=2*PIC::CPLR::DATAFILE::Offset::ElectricField.nVars*sizeof(double);
    OffsetE_HalfTimeStep=3*sizeof(double);
  }
  //allocate memory for Jx,Jy,Jz
  PIC::Mesh::cDataCornerNode::totalAssociatedDataLength+=3*sizeof(double);
  JxOffsetIndex = 6;
  JyOffsetIndex = 7;
  JzOffsetIndex = 8;
  
  //allocate memory for 81 mass matrix elements
  PIC::Mesh::cDataCornerNode::totalAssociatedDataLength+=243*sizeof(double);
  MassMatrixOffsetIndex = 9;
    
  PIC::Mesh::mesh.GetCenterNodesInterpolationCoefficients=PIC::Mesh::GetCenterNodesInterpolationCoefficients;
   
  
  PIC::Mesh::AddVaraibleListFunction(PIC::FieldSolver::Electromagnetic::ECSIM::output::PrintCenterNodeVariableList);
  PIC::Mesh::PrintDataCenterNode.push_back(PIC::FieldSolver::Electromagnetic::ECSIM::output::PrintCenterNodeData);
  PIC::Mesh::InterpolateCenterNode.push_back(PIC::FieldSolver::Electromagnetic::ECSIM::output::InterpolateCenterNode);

  PIC::Mesh::PrintVariableListCornerNode.push_back(PIC::FieldSolver::Electromagnetic::ECSIM::output::PrintCornerNodeVariableList);
  PIC::Mesh::PrintDataCornerNode.push_back(PIC::FieldSolver::Electromagnetic::ECSIM::output::PrintCornerNodeData);
  
  //  PIC::FieldSolver::Electromagnetic::ECSIM::Init_IC(); 
}

void PIC::FieldSolver::Electromagnetic::ECSIM::Init_IC() {
  //set the initial conditions
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;
  dtTotal=PIC::ParticleWeightTimeStep::GlobalTimeStep[0];
  PIC::FieldSolver::Electromagnetic::ECSIM::cDt=LightSpeed*dtTotal;
  
  PIC::FieldSolver::Electromagnetic::ECSIM::BuildMatrix();
  SetIC();
}

//set default initial conditions
void  PIC::FieldSolver::Electromagnetic::ECSIM::SetIC_default() {
  int i,j,k,iNode,idim;
  cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *node;
  PIC::Mesh::cDataCenterNode *CenterNode;
  PIC::Mesh::cDataCornerNode *CornerNode;
  PIC::Mesh::cDataBlockAMR *block;
  double *E,*B;
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;    
  if (PIC::CPLR::DATAFILE::Offset::ElectricField.active==false) exit(__LINE__,__FILE__,"Error: the electric field offset is not active");
  if (PIC::CPLR::DATAFILE::Offset::MagneticField.active==false) exit(__LINE__,__FILE__,"Error: the magnetic field offset is not active");

  //loop through all blocks
  for (int iNode=0;iNode<DomainBlockDecomposition::nLocalBlocks;iNode++) {
    node=DomainBlockDecomposition::BlockTable[iNode];
    block=node->block;

    if (block!=NULL) {      
      //set the electric field (corner nodes)
      // the loop index is changed
      for (i=0;i<_BLOCK_CELLS_X_;i++) for (j=0;j<_BLOCK_CELLS_Y_;j++) for (k=0;k<_BLOCK_CELLS_Z_;k++) {
        CornerNode=block->GetCornerNode(PIC::Mesh::cDataBlockAMR::getCornerNodeLocalNumber(i,j,k));

        if (CornerNode!=NULL) {
          E=(double*)(CornerNode->GetAssociatedDataBufferPointer()+PIC::CPLR::DATAFILE::Offset::ElectricField.RelativeOffset+CurrentEOffset);
          for (idim=0;idim<3;idim++) E[idim]=0.0;
	  E=(double*)(CornerNode->GetAssociatedDataBufferPointer()+PIC::CPLR::DATAFILE::Offset::ElectricField.RelativeOffset+OffsetE_HalfTimeStep);
          for (idim=0;idim<3;idim++) E[idim]=0.0;
        }
      }

      //set the magnetic field (center nodes)
      for (i=0;i<_BLOCK_CELLS_X_;i++) for (j=0;j<_BLOCK_CELLS_Y_;j++) for (k=0;k<_BLOCK_CELLS_Z_;k++) {
        CenterNode=block->GetCenterNode(PIC::Mesh::cDataBlockAMR::getCenterNodeLocalNumber(i,j,k));

        if (CenterNode!=NULL) {
          B=(double*)(CenterNode->GetAssociatedDataBufferPointer()+PIC::CPLR::DATAFILE::Offset::MagneticField.RelativeOffset);
          for (idim=0;idim<3;idim++) B[idim]=0.0;
        }
      }
    }
  }

  //update the 'ghost' cells and 'ghost' blocks
  switch (_PIC_BC__PERIODIC_MODE_) {
  case _PIC_BC__PERIODIC_MODE_ON_:
    PIC::BC::ExternalBoundary::Periodic::UpdateData();
    break;
  default:
    PIC::Mesh::mesh.ParallelBlockDataExchange();
  }
}

int MassMatrixOffsetTable[3][81];
bool initMassMatrixOffsetTable=false;

void computeMassMatrixOffsetTable(){

 int indexAddition[3] = {0,-1,1};
  for (int iVarIndex=0; iVarIndex<3; iVarIndex++){
    for (int ii=0;ii<3;ii++){
      for (int jj=0;jj<3;jj++){
	for (int kk=0;kk<3;kk++){
	  int iElement = iVarIndex*27+ii+jj*3+kk*9;
	  MassMatrixOffsetTable[0][iElement]=(ii+jj*3+kk*9)*9+0*3+iVarIndex;
	  MassMatrixOffsetTable[1][iElement]=(ii+jj*3+kk*9)*9+1*3+iVarIndex;
	  MassMatrixOffsetTable[2][iElement]=(ii+jj*3+kk*9)*9+2*3+iVarIndex;
	}
      }
    }
  }
  
  initMassMatrixOffsetTable=true;
}

void PIC::FieldSolver::Electromagnetic::ECSIM::GetStencil(int i,int j,int k,int iVar,cLinearSystemCornerNode<PIC::Mesh::cDataCornerNode,3,81,82,16,1,1>::cMatrixRowNonZeroElementTable* MatrixRowNonZeroElementTable,int& NonZeroElementsFound,double& rhs,
			     cLinearSystemCornerNode<PIC::Mesh::cDataCornerNode,3,81,82,16,1,1>::cRhsSupportTable* RhsSupportTable_CornerNodes,int& RhsSupportLength_CornerNodes,
			     cLinearSystemCornerNode<PIC::Mesh::cDataCornerNode,3,81,82,16,1,1>::cRhsSupportTable* RhsSupportTable_CenterNodes,int& RhsSupportLength_CenterNodes, 
			     cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *node) {
  
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;    
  // No.0-No.26  stencil Ex
  // No.27-No.53 stencil Ey
  // No.54-No.80 stencil Ez
  
  // i+indexadd[ii](ii:0,1,2), j+indexAdd[jj](jj:0,1,2), k+indexAdd[kk](kk:0,1,2)
  // index number: ii+3*jj+9*kk 
  // No.0: i,j,k No.1 i-1,j,k No.2 i+1,j,k
  // No.3: i,j-1,k No.4:i-1,j-1,k No.5 i+1,j-1,k 
  
  // double cLighgt, dt;
  double x[3];
  int index[3] = {i,j,k};
  int nCell[3] = {_BLOCK_CELLS_X_,_BLOCK_CELLS_Y_,_BLOCK_CELLS_Z_};
  double dx[3],coeff[3],coeffSqr[3],coeff4[3]; 
  for (int iDim=0; iDim<3; iDim++){
    dx[iDim]=(node->xmax[iDim]-node->xmin[iDim])/nCell[iDim];
    //convert to cgs
    // dx[iDim] *= 1e2;

    //x[iDim]=node->xmin[iDim]+index[iDim]*(node->xmax[iDim]-node->xmin[iDim])/nCell[iDim];
    // printf("dx[iDim]:%f\n",dx[iDim]);
    //coeff[iDim] = cLight*dt/dx[iDim];
    coeff[iDim] = cDt/dx[iDim]*theta; // for  test purpose
    coeffSqr[iDim] = coeff[iDim]*coeff[iDim];
    //coeffSqr[iDim] = 0.5/dx[iDim]/dx[iDim];
    coeff4[iDim] = coeff[iDim]*0.25; //coefficients for curl calculation
    //   printf("coeff[iDim]:%f, coeffSqr[iDim]:%f\n",coeff[iDim],coeffSqr[iDim]);
  }

  if (!initMassMatrixOffsetTable) computeMassMatrixOffsetTable(); 

  int indexAddition[3] = {0,-1,1};
  char * NodeDataOffset = node->block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,j,k))->GetAssociatedDataBufferPointer();
  for (int iVarIndex=0; iVarIndex<3; iVarIndex++){
    for (int ii=0;ii<3;ii++){
      for (int jj=0;jj<3;jj++){
	for (int kk=0;kk<3;kk++){
	  int iNode = i+indexAddition[ii];
	  int jNode = j+indexAddition[jj];
	  int kNode = k+indexAddition[kk];
	  int iElement = iVarIndex*27+ii+jj*3+kk*9;
	    
	  MatrixRowNonZeroElementTable[iElement].i=iNode;
	  MatrixRowNonZeroElementTable[iElement].j=jNode;
	  MatrixRowNonZeroElementTable[iElement].k=kNode;
	    // already initialized in LinearSystemSolver.h 
	    //MatrixRowNonZeroElementTable[iElement].MatrixElementValue=0.0;
	  MatrixRowNonZeroElementTable[iElement].iVar=iVarIndex;
	  MatrixRowNonZeroElementTable[iElement].MatrixElementParameterTable[0]=0.0; 
	  MatrixRowNonZeroElementTable[iElement].MatrixElementParameterTableLength=1;
	  MatrixRowNonZeroElementTable[iElement].MatrixElementSupportTableLength = 1;
	  //question question
	  MatrixRowNonZeroElementTable[iElement].MatrixElementSupportTable[0]=(double*)NodeDataOffset+MassMatrixOffsetIndex+MassMatrixOffsetTable[iVar][iElement];
	}
      }
    }
  }
    
  //laplacian
  for (int iDim=0;iDim<3; iDim++){
    int IndexOption[2]={1,2};
    for (int iOpt=0;iOpt<2;iOpt++){
      
      int ii = (iDim!=0)?0:IndexOption[iOpt];
      int jj = (iDim!=1)?0:IndexOption[iOpt];
      int kk = (iDim!=2)?0:IndexOption[iOpt];
      int iElement= iVar*27+ii+jj*3+kk*9;
       	//MatrixRowNonZeroElementTable[iElement].MatrixElementValue -= coeffSqr[iDim];
      MatrixRowNonZeroElementTable[iElement].MatrixElementParameterTable[0] -= coeffSqr[iDim];
	//	printf("test1:%f\n",MatrixRowNonZeroElementTable[iElement].MatrixElementParameterTable[0] );
    }
  }
  //self i,j,k  iVar
  //    MatrixRowNonZeroElementTable[iVar*27].MatrixElementValue += 2*(coeffSqr[0]+coeffSqr[1]+coeffSqr[2])+1;
  MatrixRowNonZeroElementTable[iVar*27].MatrixElementParameterTable[0] += 2*(coeffSqr[0]+coeffSqr[1]+coeffSqr[2])+1;  
  // printf("test2:%f\n",MatrixRowNonZeroElementTable[iVar*27].MatrixElementParameterTable[0] );
   
 
  // dt2 E_ivar/d2 ivar
  // eg. Ex,i,j,
  // MatrixRowNonZeroElementTable[27*iVar].MatrixElementValue -= 2*coeffSqr[iVar];
  MatrixRowNonZeroElementTable[iVar*27].MatrixElementParameterTable[0] -= 2*coeffSqr[iVar]; 
  // printf("test3:%f\n",MatrixRowNonZeroElementTable[iVar*27].MatrixElementParameterTable[0] );
  // eg. Ex, i-1,j,k and i+1,j,k;  Ey, i,j-1,k and i,j+1,k

  int tempInd =pow(3,iVar);//iVar=0:1; iVar=1:3; iVar=2:9

  //   MatrixRowNonZeroElementTable[27*iVar+tempInd].MatrixElementValue += coeffSqr[iVar];
  MatrixRowNonZeroElementTable[27*iVar+tempInd].MatrixElementParameterTable[0] += coeffSqr[iVar];
  // printf("test4:%f\n",MatrixRowNonZeroElementTable[iVar*27+tempInd].MatrixElementParameterTable[0] );
  //MatrixRowNonZeroElementTable[27*iVar+2*tempInd].MatrixElementValue += coeffSqr[iVar];
  MatrixRowNonZeroElementTable[27*iVar+2*tempInd].MatrixElementParameterTable[0] += coeffSqr[iVar]; 
  
  int iVarNext = (iVar+4)%3;
  int iVarPrev = (iVar+2)%3;

  for (int ii=0; ii<2; ii++){
    for (int jj=0;jj<2; jj++){
      /* int iNode,jNode,kNode;
      int * indexValuePtr[3] = {&iNode,&jNode,&kNode}; 
      for (int iDim=0;iDim<3;iDim++) {
	if (iDim==iVarPrev) *indexValuePtr[iDim]=index[iDim];
	if (iDim==iVar) *indexValuePtr[iDim]=index[iDim]+indexAdd[ii];
	if (iDim==iVarNext) *indexValuePtr[iDim]=index[iDim]+indexAdd[jj];
      }
      */
      int iElement=(ii+1)*pow(3,iVar)+(jj+1)*pow(3,iVarNext)+iVarNext*27;
      double tempCoeff = 0.25*coeff[iVar]*coeff[iVarNext];
      if (ii!=jj) tempCoeff *= -1;
      //	  MatrixRowNonZeroElementTable[iElement].MatrixElementValue += tempCoeff;
      MatrixRowNonZeroElementTable[iElement].MatrixElementParameterTable[0] += tempCoeff;	  
    } 
  }     

  for (int ii=0; ii<2; ii++){
    for (int jj=0;jj<2;jj++){
      /*
      int iNode,jNode,kNode;
      int * indexValuePtr[3] = {&iNode,&jNode,&kNode}; 
      for (int iDim=0;iDim<3;iDim++) {
	if (iDim==iVarNext) *indexValuePtr[iDim]=index[iDim];
	if (iDim==iVar) *indexValuePtr[iDim]=index[iDim]+indexAdd[ii];
	if (iDim==iVarPrev) *indexValuePtr[iDim]=index[iDim]+indexAdd[jj];
      }
      */
      int iElement=(ii+1)*pow(3,iVar)+(jj+1)*pow(3,iVarPrev)+iVarPrev*27;
      double tempCoeff = 0.25*coeff[iVar]*coeff[iVarPrev];
      if (ii!=jj) tempCoeff *= -1;
      //MatrixRowNonZeroElementTable[iElement].MatrixElementValue += tempCoeff;
      MatrixRowNonZeroElementTable[iElement].MatrixElementParameterTable[0] += tempCoeff;
    } 
  }     

  NonZeroElementsFound=81;

  //  for (int iVarIndex=0; iVarIndex<3; iVarIndex++){

    // fill first 27 elements
  for (int ii=0;ii<3;ii++){
    for (int jj=0;jj<3;jj++){
      for (int kk=0;kk<3;kk++){
	int iNode = i+indexAddition[ii];
	int jNode = j+indexAddition[jj];
	int kNode = k+indexAddition[kk];
	int iElement = ii+jj*3+kk*9;
	
	RhsSupportTable_CornerNodes[iElement].Coefficient= 0.0;
	RhsSupportTable_CornerNodes[iElement].AssociatedDataPointer=node->block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(iNode,jNode,kNode))->GetAssociatedDataBufferPointer();
      }
    }
  }
      // }

  for (int iVarIndex=1; iVarIndex<3; iVarIndex++){
    // fill next 54 elements
    for (int ii=0;ii<3;ii++){
      for (int jj=0;jj<3;jj++){
	for (int kk=0;kk<3;kk++){
	  int iNode = i+indexAddition[ii];
	  int jNode = j+indexAddition[jj];
	  int kNode = k+indexAddition[kk];
	  int iElement = iVarIndex*27+ii+jj*3+kk*9;
	  int jOldElement = ii+jj*3+kk*9;
	  
	  RhsSupportTable_CornerNodes[iElement].Coefficient= 0.0;
	  RhsSupportTable_CornerNodes[iElement].AssociatedDataPointer=RhsSupportTable_CornerNodes[jOldElement].AssociatedDataPointer;
	}
      }
    }
  }
  
    
  // iVar laplacian
  for (int ii=0;ii<3; ii++){
    int addition[2]={-1,1};
    for (int jj=0;jj<2;jj++){             
 
      int iElement = iVar*27+(jj+1)*pow(3,ii);
      RhsSupportTable_CornerNodes[iElement].Coefficient += coeffSqr[ii];
    }
  }
   
  
  //self i,j,k
  RhsSupportTable_CornerNodes[iVar*27].Coefficient=-2*(coeffSqr[0]+coeffSqr[1]+coeffSqr[2]);
            
  // current j locate at the same node as E_{i,j,k}
  RhsSupportTable_CornerNodes[81].AssociatedDataPointer=RhsSupportTable_CornerNodes[iVar*27].AssociatedDataPointer;
  RhsSupportTable_CornerNodes[81].Coefficient=-4*Pi*dtTotal*theta;

  
  RhsSupportTable_CornerNodes[iVar*27].Coefficient += 2*coeffSqr[iVar]; 
  // printf("test3:%f\n",MatrixRowNonZeroElementTable[iVar*27].MatrixElementParameterTable[0] );
  // eg. Ex, i-1,j,k and i+1,j,k;  Ey, i,j-1,k and i,j+1,k
  tempInd =pow(3,iVar);//iVar=0:1; iVar=1:3; iVar=2:9
  //   MatrixRowNonZeroElementTable[27*iVar+tempInd].MatrixElementValue += coeffSqr[iVar];
  RhsSupportTable_CornerNodes[27*iVar+tempInd].Coefficient -= coeffSqr[iVar];
  // printf("test4:%f\n",MatrixRowNonZeroElementTable[iVar*27+tempInd].MatrixElementParameterTable[0] );
  //MatrixRowNonZeroElementTable[27*iVar+2*tempInd].MatrixElementValue += coeffSqr[iVar];
  RhsSupportTable_CornerNodes[27*iVar+2*tempInd].Coefficient -= coeffSqr[iVar]; 
 
      
  /* defined before
     int iVarNext = (iVar+4)%3;
     int iVarPrev = (iVar+2)%3;
     int indexAdd[2] ={-1,1};
  */
  for (int ii=0; ii<2; ii++){
    for (int jj=0;jj<2;jj++){
      /*
      int iNode,jNode,kNode;
      int * indexValuePtr[3] = {&iNode,&jNode,&kNode}; 
      for (int iDim=0;iDim<3;iDim++) {
	if (iDim==iVarPrev) *indexValuePtr[iDim]=index[iDim];
	if (iDim==iVar) *indexValuePtr[iDim]=index[iDim]+indexAdd[ii];
	if (iDim==iVarNext) *indexValuePtr[iDim]=index[iDim]+indexAdd[jj];
      }
      */
      int iElement=(ii+1)*pow(3,iVar)+(jj+1)*pow(3,iVarNext)+iVarNext*27;
      double tempCoeff = -0.25*coeff[iVar]*coeff[iVarNext];
      if (ii!=jj) tempCoeff *= -1;
      RhsSupportTable_CornerNodes[iElement].Coefficient += tempCoeff;
      
    } 
  }     
  

  for (int ii=0; ii<2; ii++){
    for (int jj=0;jj<2;jj++){
      /*
      int iNode,jNode,kNode;
      int * indexValuePtr[3] = {&iNode,&jNode,&kNode}; 
      for (int iDim=0;iDim<3;iDim++) {
	if (iDim==iVarNext) *indexValuePtr[iDim]=index[iDim];
	if (iDim==iVar) *indexValuePtr[iDim]=index[iDim]+indexAdd[ii];
	if (iDim==iVarPrev) *indexValuePtr[iDim]=index[iDim]+indexAdd[jj];
      }
      */
      int iElement=(ii+1)*pow(3,iVar)+(jj+1)*pow(3,iVarPrev)+iVarPrev*27;
      double tempCoeff = -0.25*coeff[iVar]*coeff[iVarPrev];
      if (ii!=jj) tempCoeff *= -1;
      RhsSupportTable_CornerNodes[iElement].Coefficient += tempCoeff;
      
    } 
  }     
  
  RhsSupportLength_CornerNodes=82;

    
   
    //Ex^n,Ey^n,Ez^n
    rhs=0.0;

    //compute the right hand side
    /*
      for (int ii=0;ii<27;ii++) {
      double * tempPtr = (double*)(RhsSupportTable_CornerNodes[ii].AssociatedDataPointer+CurrentCornerNodeOffset);
      rhs+=tempPtr[ExOffsetIndex]*RhsSupportTable_CornerNodes[ii].Coefficient+
	tempPtr[EyOffsetIndex]*RhsSupportTable_CornerNodes[ii+27].Coefficient+
	tempPtr[EzOffsetIndex]*RhsSupportTable_CornerNodes[ii+54].Coefficient;
    }

    rhs+=((double*)(RhsSupportTable_CornerNodes[81].AssociatedDataPointer+CurrentCornerNodeOffset))[JxOffsetIndex+iVar]*
      RhsSupportTable_CornerNodes[81].Coefficient;
    */
 
    int indexAdditionB[2] = {-1,0};
    
    int iElement = 0;
   
    double curlB = 0.0;
    //Ex  rhs+= d Bz/dy - d By/dz
    if (iVar==0){
          
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=coeff4[1]; //c(dt)/dy
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[ii],j,k+indexAdditionB[jj]))->GetAssociatedDataBufferPointer();
	  //  rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BzOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	  
	}
      }

      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=-coeff4[1]; //-c(dt)/dy
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[ii],j-1,k+indexAdditionB[jj]))->GetAssociatedDataBufferPointer();
	  // rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BzOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
      
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=-coeff4[2]; //-c(dt)/dz
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[ii],j+indexAdditionB[jj],k))->GetAssociatedDataBufferPointer();
	  //  rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[ByOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
    
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=coeff4[2]; //c(dt)/dz
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[ii],j+indexAdditionB[jj],k-1))->GetAssociatedDataBufferPointer();
	  // rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[ByOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
    
    }

     //Ey  rhs+= d Bx/dz - d Bz/dx
    if (iVar==1){
     
      
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=coeff4[2]; //c(dt)/dz
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[ii],j+indexAdditionB[jj],k))->GetAssociatedDataBufferPointer();
	  // rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  // curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	  
	}
      }

      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=-coeff4[2]; //-c(dt)/dz
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[ii],j+indexAdditionB[jj],k-1))->GetAssociatedDataBufferPointer();
	  //rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
      
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=-coeff4[0]; //-c(dt)/dx
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i,j+indexAdditionB[jj],k+indexAdditionB[ii]))->GetAssociatedDataBufferPointer();
	  //rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BzOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BzOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
    
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=coeff4[0]; //c(dt)/dx
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i-1,j+indexAdditionB[jj],k+indexAdditionB[ii]))->GetAssociatedDataBufferPointer();
	  // rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BzOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BzOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
      
      // double analytic = -1000*3.14159265/2*cos((x[0]+1)*3.14159265/2)*0.2;
      //printf("Ey,curlB:%f,analytic:%f\n", curlB, analytic);
      //rhs+=curlB;
    }
    
    //Ez  rhs+= d By/dx - d Bx/dy
    if (iVar==2){
     
     
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=coeff4[0]; //c(dt)/dx
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i,j+indexAdditionB[jj],k+indexAdditionB[ii]))->GetAssociatedDataBufferPointer();
	  //rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[ByOffsetIndex]*RhsSupportTable_CenterNodes[ii].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[ByOffsetIndex]*RhsSupportTable_CenterNodes[ii].Coefficient;
	  iElement++;
	}
      }

      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=-coeff4[0]; //-c(dt)/dx
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i-1,j+indexAdditionB[jj],k+indexAdditionB[ii]))->GetAssociatedDataBufferPointer();
	  //rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[ByOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[ByOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
      
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=-coeff4[1]; //-c(dt)/dy
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[jj],j,k+indexAdditionB[ii]))->GetAssociatedDataBufferPointer();
	  //rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
    
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=coeff4[1]; //c(dt)/dy
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[jj],j-1,k+indexAdditionB[ii]))->GetAssociatedDataBufferPointer();
	  //rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }

      //double analytic = -1000*3.14159265/2*cos((x[0]+1)*3.14159265/2)*0.2;
      //printf("Ez,curlB:%f,analytic:%f\n", curlB, analytic);
      //rhs+=curlB;
    }
   
    RhsSupportLength_CenterNodes = iElement;     
}



//create the stencil 
void GetStencilOld(int i,int j,int k,int iVar,cLinearSystemCornerNode<PIC::Mesh::cDataCornerNode,3,81,82,16,1,1>::cMatrixRowNonZeroElementTable* MatrixRowNonZeroElementTable,int& NonZeroElementsFound,double& rhs,
			     cLinearSystemCornerNode<PIC::Mesh::cDataCornerNode,3,81,82,16,1,1>::cRhsSupportTable* RhsSupportTable_CornerNodes,int& RhsSupportLength_CornerNodes,
			     cLinearSystemCornerNode<PIC::Mesh::cDataCornerNode,3,81,82,16,1,1>::cRhsSupportTable* RhsSupportTable_CenterNodes,int& RhsSupportLength_CenterNodes, 
			     cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *node) {
  
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;    
  // No.0-No.26  stencil Ex
  // No.27-No.53 stencil Ey
  // No.54-No.80 stencil Ez
  
  // i+indexadd[ii](ii:0,1,2), j+indexAdd[jj](jj:0,1,2), k+indexAdd[kk](kk:0,1,2)
  // index number: ii+3*jj+9*kk 
  // No.0: i,j,k No.1 i-1,j,k No.2 i+1,j,k
  // No.3: i,j-1,k No.4:i-1,j-1,k No.5 i+1,j-1,k 
  
  // double cLighgt, dt;
  double x[3];
  int index[3] = {i,j,k};
  int nCell[3] = {_BLOCK_CELLS_X_,_BLOCK_CELLS_Y_,_BLOCK_CELLS_Z_};
  double dx[3],coeff[3],coeffSqr[3],coeff4[3]; 
  for (int iDim=0; iDim<3; iDim++){
    dx[iDim]=(node->xmax[iDim]-node->xmin[iDim])/nCell[iDim];
    x[iDim]=node->xmin[iDim]+index[iDim]*(node->xmax[iDim]-node->xmin[iDim])/nCell[iDim];
    // printf("dx[iDim]:%f\n",dx[iDim]);
    //coeff[iDim] = cLight*dt/dx[iDim];
    coeff[iDim] = cDt/dx[iDim]*theta; // for  test purpose
    coeffSqr[iDim] = coeff[iDim]*coeff[iDim];
    //coeffSqr[iDim] = 0.5/dx[iDim]/dx[iDim];
    coeff4[iDim] = coeff[iDim]*0.25; //coefficients for curl calculation
    //   printf("coeff[iDim]:%f, coeffSqr[iDim]:%f\n",coeff[iDim],coeffSqr[iDim]);
  }

  if (!initMassMatrixOffsetTable) computeMassMatrixOffsetTable(); 

  int indexAddition[3] = {0,-1,1};
  for (int iVarIndex=0; iVarIndex<3; iVarIndex++){
    for (int ii=0;ii<3;ii++){
      for (int jj=0;jj<3;jj++){
	for (int kk=0;kk<3;kk++){
	  int iNode = i+indexAddition[ii];
	  int jNode = j+indexAddition[jj];
	  int kNode = k+indexAddition[kk];
	  int iElement = iVarIndex*27+ii+jj*3+kk*9;
	    
	  MatrixRowNonZeroElementTable[iElement].i=iNode;
	  MatrixRowNonZeroElementTable[iElement].j=jNode;
	  MatrixRowNonZeroElementTable[iElement].k=kNode;
	    // already initialized in LinearSystemSolver.h 
	    //MatrixRowNonZeroElementTable[iElement].MatrixElementValue=0.0;
	  MatrixRowNonZeroElementTable[iElement].iVar=iVarIndex;
	  MatrixRowNonZeroElementTable[iElement].MatrixElementParameterTable[0]=0.0; 
	  MatrixRowNonZeroElementTable[iElement].MatrixElementParameterTableLength=1;
	  MatrixRowNonZeroElementTable[iElement].MatrixElementSupportTableLength = 1;
	  //question question
	  MatrixRowNonZeroElementTable[iElement].MatrixElementSupportTable[0]=((double*)node->block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,j,k))->GetAssociatedDataBufferPointer())+MassMatrixOffsetIndex+MassMatrixOffsetTable[iVar][iElement];
	}
      }
    }
  }
    
 
  for (int iDim=0;iDim<3; iDim++){
    int IndexOption[2]={1,2};
    for (int iOpt=0;iOpt<2;iOpt++){
      
      int ii = (iDim!=0)?0:IndexOption[iOpt];
      int jj = (iDim!=1)?0:IndexOption[iOpt];
      int kk = (iDim!=2)?0:IndexOption[iOpt];
      int iElement= iVar*27+ii+jj*3+kk*9;
       	//MatrixRowNonZeroElementTable[iElement].MatrixElementValue -= coeffSqr[iDim];
      MatrixRowNonZeroElementTable[iElement].MatrixElementParameterTable[0] -= coeffSqr[iDim];
	//	printf("test1:%f\n",MatrixRowNonZeroElementTable[iElement].MatrixElementParameterTable[0] );
    }
  }
  //self i,j,k  iVar
  //    MatrixRowNonZeroElementTable[iVar*27].MatrixElementValue += 2*(coeffSqr[0]+coeffSqr[1]+coeffSqr[2])+1;
  MatrixRowNonZeroElementTable[iVar*27].MatrixElementParameterTable[0] += 2*(coeffSqr[0]+coeffSqr[1]+coeffSqr[2])+1;  
  // printf("test2:%f\n",MatrixRowNonZeroElementTable[iVar*27].MatrixElementParameterTable[0] );
   
 
  // dt2 E_ivar/d2 ivar
  // eg. Ex,i,j,
  // MatrixRowNonZeroElementTable[27*iVar].MatrixElementValue -= 2*coeffSqr[iVar];
  MatrixRowNonZeroElementTable[iVar*27].MatrixElementParameterTable[0] -= 2*coeffSqr[iVar]; 
  // printf("test3:%f\n",MatrixRowNonZeroElementTable[iVar*27].MatrixElementParameterTable[0] );
  // eg. Ex, i-1,j,k and i+1,j,k;  Ey, i,j-1,k and i,j+1,k

  int tempInd =pow(3,iVar);//iVar=0:1; iVar=1:3; iVar=2:9

  //   MatrixRowNonZeroElementTable[27*iVar+tempInd].MatrixElementValue += coeffSqr[iVar];
  MatrixRowNonZeroElementTable[27*iVar+tempInd].MatrixElementParameterTable[0] += coeffSqr[iVar];
  // printf("test4:%f\n",MatrixRowNonZeroElementTable[iVar*27+tempInd].MatrixElementParameterTable[0] );
  //MatrixRowNonZeroElementTable[27*iVar+2*tempInd].MatrixElementValue += coeffSqr[iVar];
  MatrixRowNonZeroElementTable[27*iVar+2*tempInd].MatrixElementParameterTable[0] += coeffSqr[iVar]; 
  
  int iVarNext = (iVar+4)%3;
  int iVarPrev = (iVar+2)%3;

  int indexAdd[2]={-1,1};
  for (int ii=0; ii<2; ii++){
    for (int jj=0;jj<2; jj++){
      int iNode,jNode,kNode;
      int * indexValuePtr[3] = {&iNode,&jNode,&kNode}; 
      for (int iDim=0;iDim<3;iDim++) {
	if (iDim==iVarPrev) *indexValuePtr[iDim]=index[iDim];
	if (iDim==iVar) *indexValuePtr[iDim]=index[iDim]+indexAdd[ii];
	if (iDim==iVarNext) *indexValuePtr[iDim]=index[iDim]+indexAdd[jj];
      }
      int iElement=(ii+1)*pow(3,iVar)+(jj+1)*pow(3,iVarNext)+iVarNext*27;
      double tempCoeff = 0.25*coeff[iVar]*coeff[iVarNext];
      if (ii!=jj) tempCoeff *= -1;
      //	  MatrixRowNonZeroElementTable[iElement].MatrixElementValue += tempCoeff;
      MatrixRowNonZeroElementTable[iElement].MatrixElementParameterTable[0] += tempCoeff;	  
    } 
  }     

  for (int ii=0; ii<2; ii++){
    for (int jj=0;jj<2;jj++){
      int iNode,jNode,kNode;
      int * indexValuePtr[3] = {&iNode,&jNode,&kNode}; 
      for (int iDim=0;iDim<3;iDim++) {
	if (iDim==iVarNext) *indexValuePtr[iDim]=index[iDim];
	if (iDim==iVar) *indexValuePtr[iDim]=index[iDim]+indexAdd[ii];
	if (iDim==iVarPrev) *indexValuePtr[iDim]=index[iDim]+indexAdd[jj];
      }
      int iElement=(ii+1)*pow(3,iVar)+(jj+1)*pow(3,iVarPrev)+iVarPrev*27;
      double tempCoeff = 0.25*coeff[iVar]*coeff[iVarPrev];
      if (ii!=jj) tempCoeff *= -1;
      //MatrixRowNonZeroElementTable[iElement].MatrixElementValue += tempCoeff;
      MatrixRowNonZeroElementTable[iElement].MatrixElementParameterTable[0] += tempCoeff;
    } 
  }     

  NonZeroElementsFound=81;

  //  for (int iVarIndex=0; iVarIndex<3; iVarIndex++){

    // fill first 27 elements
  for (int ii=0;ii<3;ii++){
    for (int jj=0;jj<3;jj++){
      for (int kk=0;kk<3;kk++){
	int iNode = i+indexAddition[ii];
	int jNode = j+indexAddition[jj];
	int kNode = k+indexAddition[kk];
	int iElement = ii+jj*3+kk*9;
	
	RhsSupportTable_CornerNodes[iElement].Coefficient= 0.0;
	RhsSupportTable_CornerNodes[iElement].AssociatedDataPointer=node->block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(iNode,jNode,kNode))->GetAssociatedDataBufferPointer();
      }
    }
  }
      // }

  for (int iVarIndex=1; iVarIndex<3; iVarIndex++){
    // fill next 54 elements
    for (int ii=0;ii<3;ii++){
      for (int jj=0;jj<3;jj++){
	for (int kk=0;kk<3;kk++){
	  int iNode = i+indexAddition[ii];
	  int jNode = j+indexAddition[jj];
	  int kNode = k+indexAddition[kk];
	  int iElement = iVarIndex*27+ii+jj*3+kk*9;
	  int jOldElement = ii+jj*3+kk*9;
	  
	  RhsSupportTable_CornerNodes[iElement].Coefficient= 0.0;
	  RhsSupportTable_CornerNodes[iElement].AssociatedDataPointer=RhsSupportTable_CornerNodes[jOldElement].AssociatedDataPointer;
	}
      }
    }
  }

  // iVar
  for (int ii=0;ii<3; ii++){
    int addition[2]={-1,1};
    for (int jj=0;jj<2;jj++){             
      /* the node index
	 int iNode=(ii!=0)?i:i+addition[jj];
	 int jNode=(ii!=1)?j:j+addition[jj];
	 int kNode=(ii!=2)?k:k+addition[jj];
      */
      int iElement = iVar*27+(jj+1)*pow(3,ii);
      RhsSupportTable_CornerNodes[iElement].Coefficient += coeffSqr[ii];
    }
  }
    
  //self i,j,k
  RhsSupportTable_CornerNodes[iVar*27].Coefficient -=2*(coeffSqr[0]+coeffSqr[1]+coeffSqr[2]);
            
  // current j locate at the same node as E_{i,j,k}
  RhsSupportTable_CornerNodes[81].AssociatedDataPointer=RhsSupportTable_CornerNodes[iVar*27].AssociatedDataPointer;
  RhsSupportTable_CornerNodes[81].Coefficient=-4*Pi*dtTotal*theta;
      
  

  RhsSupportTable_CornerNodes[iVar*27].Coefficient += 2*coeffSqr[iVar]; 
  // printf("test3:%f\n",MatrixRowNonZeroElementTable[iVar*27].MatrixElementParameterTable[0] );
  // eg. Ex, i-1,j,k and i+1,j,k;  Ey, i,j-1,k and i,j+1,k

  tempInd =pow(3,iVar);//iVar=0:1; iVar=1:3; iVar=2:9

  //   MatrixRowNonZeroElementTable[27*iVar+tempInd].MatrixElementValue += coeffSqr[iVar];
  RhsSupportTable_CornerNodes[27*iVar+tempInd].Coefficient -= coeffSqr[iVar];
  // printf("test4:%f\n",MatrixRowNonZeroElementTable[iVar*27+tempInd].MatrixElementParameterTable[0] );
  //MatrixRowNonZeroElementTable[27*iVar+2*tempInd].MatrixElementValue += coeffSqr[iVar];
  RhsSupportTable_CornerNodes[27*iVar+2*tempInd].Coefficient -= coeffSqr[iVar]; 


  /* defined before
     int iVarNext = (iVar+4)%3;
     int iVarPrev = (iVar+2)%3;
     int indexAdd[2] ={-1,1};
  */
  for (int ii=0; ii<2; ii++){
    for (int jj=0;jj<2;jj++){
      int iNode,jNode,kNode;
      int * indexValuePtr[3] = {&iNode,&jNode,&kNode}; 
      for (int iDim=0;iDim<3;iDim++) {
	if (iDim==iVarPrev) *indexValuePtr[iDim]=index[iDim];
	if (iDim==iVar) *indexValuePtr[iDim]=index[iDim]+indexAdd[ii];
	if (iDim==iVarNext) *indexValuePtr[iDim]=index[iDim]+indexAdd[jj];
      }
      int iElement=(ii+1)*pow(3,iVar)+(jj+1)*pow(3,iVarNext)+iVarNext*27;
      double tempCoeff = -0.25*coeff[iVar]*coeff[iVarNext];
      if (ii!=jj) tempCoeff *= -1;
      RhsSupportTable_CornerNodes[iElement].Coefficient += tempCoeff;
      
    } 
  }     
  

  for (int ii=0; ii<2; ii++){
    for (int jj=0;jj<2;jj++){
      int iNode,jNode,kNode;
      int * indexValuePtr[3] = {&iNode,&jNode,&kNode}; 
      for (int iDim=0;iDim<3;iDim++) {
	if (iDim==iVarNext) *indexValuePtr[iDim]=index[iDim];
	if (iDim==iVar) *indexValuePtr[iDim]=index[iDim]+indexAdd[ii];
	if (iDim==iVarPrev) *indexValuePtr[iDim]=index[iDim]+indexAdd[jj];
      }
      int iElement=(ii+1)*pow(3,iVar)+(jj+1)*pow(3,iVarPrev)+iVarPrev*27;
      double tempCoeff = -0.25*coeff[iVar]*coeff[iVarPrev];
      if (ii!=jj) tempCoeff *= -1;
      RhsSupportTable_CornerNodes[iElement].Coefficient += tempCoeff;
      
    } 
  }     
  
  RhsSupportLength_CornerNodes=82;

    
   
    //Ex^n,Ey^n,Ez^n
    rhs=0.0;

    //compute the right hand side
    /*
      for (int ii=0;ii<27;ii++) {
      double * tempPtr = (double*)(RhsSupportTable_CornerNodes[ii].AssociatedDataPointer+CurrentCornerNodeOffset);
      rhs+=tempPtr[ExOffsetIndex]*RhsSupportTable_CornerNodes[ii].Coefficient+
	tempPtr[EyOffsetIndex]*RhsSupportTable_CornerNodes[ii+27].Coefficient+
	tempPtr[EzOffsetIndex]*RhsSupportTable_CornerNodes[ii+54].Coefficient;
    }

    rhs+=((double*)(RhsSupportTable_CornerNodes[81].AssociatedDataPointer+CurrentCornerNodeOffset))[JxOffsetIndex+iVar]*
      RhsSupportTable_CornerNodes[81].Coefficient;
    */
 
    int indexAdditionB[2] = {-1,0};
    
    int iElement = 0;
   
    double curlB = 0.0;
    //Ex  rhs+= d Bz/dy - d By/dz
    if (iVar==0){
          
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=coeff4[1]; //c(dt)/dy
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[ii],j,k+indexAdditionB[jj]))->GetAssociatedDataBufferPointer();
	  //  rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BzOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	  
	}
      }

      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=-coeff4[1]; //-c(dt)/dy
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[ii],j-1,k+indexAdditionB[jj]))->GetAssociatedDataBufferPointer();
	  // rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BzOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
      
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=-coeff4[2]; //-c(dt)/dz
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[ii],j+indexAdditionB[jj],k))->GetAssociatedDataBufferPointer();
	  //  rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[ByOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
    
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=coeff4[2]; //c(dt)/dz
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[ii],j+indexAdditionB[jj],k-1))->GetAssociatedDataBufferPointer();
	  // rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[ByOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
    
    }

     //Ey  rhs+= d Bx/dz - d Bz/dx
    if (iVar==1){
     
      
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=coeff4[2]; //c(dt)/dz
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[ii],j+indexAdditionB[jj],k))->GetAssociatedDataBufferPointer();
	  // rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  // curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	  
	}
      }

      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=-coeff4[2]; //-c(dt)/dz
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[ii],j+indexAdditionB[jj],k-1))->GetAssociatedDataBufferPointer();
	  //rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
      
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=-coeff4[0]; //-c(dt)/dx
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i,j+indexAdditionB[jj],k+indexAdditionB[ii]))->GetAssociatedDataBufferPointer();
	  //rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BzOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BzOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
    
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=coeff4[0]; //c(dt)/dx
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i-1,j+indexAdditionB[jj],k+indexAdditionB[ii]))->GetAssociatedDataBufferPointer();
	  // rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BzOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BzOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
      
      // double analytic = -1000*3.14159265/2*cos((x[0]+1)*3.14159265/2)*0.2;
      //printf("Ey,curlB:%f,analytic:%f\n", curlB, analytic);
      //rhs+=curlB;
    }
    
    //Ez  rhs+= d By/dx - d Bx/dy
    if (iVar==2){
     
     
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=coeff4[0]; //c(dt)/dx
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i,j+indexAdditionB[jj],k+indexAdditionB[ii]))->GetAssociatedDataBufferPointer();
	  //rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[ByOffsetIndex]*RhsSupportTable_CenterNodes[ii].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[ByOffsetIndex]*RhsSupportTable_CenterNodes[ii].Coefficient;
	  iElement++;
	}
      }

      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=-coeff4[0]; //-c(dt)/dx
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i-1,j+indexAdditionB[jj],k+indexAdditionB[ii]))->GetAssociatedDataBufferPointer();
	  //rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[ByOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[ByOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
      
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=-coeff4[1]; //-c(dt)/dy
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[jj],j,k+indexAdditionB[ii]))->GetAssociatedDataBufferPointer();
	  //rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }
    
      for (int ii=0;ii<2;ii++){
	for (int jj=0;jj<2;jj++){
	  RhsSupportTable_CenterNodes[iElement].Coefficient=coeff4[1]; //c(dt)/dy
	  RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i+indexAdditionB[jj],j-1,k+indexAdditionB[ii]))->GetAssociatedDataBufferPointer();
	  //rhs+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  //curlB+=((double*)(RhsSupportTable_CenterNodes[iElement].AssociatedDataPointer+CurrentCenterNodeOffset))[BxOffsetIndex]*RhsSupportTable_CenterNodes[iElement].Coefficient;
	  iElement++;
	}
      }

      //double analytic = -1000*3.14159265/2*cos((x[0]+1)*3.14159265/2)*0.2;
      //printf("Ez,curlB:%f,analytic:%f\n", curlB, analytic);
      //rhs+=curlB;
    }
   
    RhsSupportLength_CenterNodes = iElement;     
}

int IndexMatrix[8][8]={{0,2,8,6,18,20,26,24},{1,0,6,7,19,18,24,25},{4,3,0,1,22,21,18,19},
			  {3,5,2,0,21,23,20,18},{9,11,17,15,0,2,8,6},{10,9,15,16,1,0,6,7},
			  {13,12,9,10,4,3,0,1},{12,14,11,9,3,5,2,0}};



void UpdateJMassMatrix(){
  // update J and MassMatrix 
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM; 
  //the table of cells' particles
  long int FirstCellParticleTable[_BLOCK_CELLS_X_*_BLOCK_CELLS_Y_*_BLOCK_CELLS_Z_];
  PIC::ParticleBuffer::byte *ParticleData,*ParticleDataNext;
  PIC::Mesh::cDataCenterNode *cell;
  PIC::Mesh::cDataBlockAMR *block;
  long int LocalCellNumber,ptr,ptrNext;    
  //temporaty buffer to store the copy of the particle
  char tempParticleData[PIC::ParticleBuffer::ParticleDataLength];
  double ParticleEnergy=0.0;

  //init J and MassMatrix to 0
  for (int nLocalNode=0;nLocalNode<PIC::DomainBlockDecomposition::nLocalBlocks;nLocalNode++) {
      
    cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *node=PIC::DomainBlockDecomposition::BlockTable[nLocalNode];
    if (_PIC_BC__PERIODIC_MODE_==_PIC_BC__PERIODIC_MODE_ON_) {
      bool BoundaryBlock=false;
      
      for (int iface=0;iface<6;iface++) if (node->GetNeibFace(iface,0,0)==NULL) {
	  //the block is at the domain boundary, and thresefor it is a 'ghost' block that is used to impose the periodic boundary conditions
	  BoundaryBlock=true;
	  break;
	}
      
      if (BoundaryBlock==true) continue;
    }

    if (node->Thread!=PIC::ThisThread) continue;
     
    block=node->block;
    
    for (int k=0;k<_BLOCK_CELLS_Z_;k++) {
      for (int j=0;j<_BLOCK_CELLS_Y_;j++)  {
        for (int i=0;i<_BLOCK_CELLS_X_;i++) {
	  char * offset=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,j,k))->GetAssociatedDataBufferPointer();
	  for (int ii=0;ii<3;ii++)   ((double*)offset)[JxOffsetIndex+ii]=0.0;
	  for (int ii=0;ii<243;ii++) ((double*)offset)[MassMatrixOffsetIndex+ii]=0.0;
	}
      }
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


  int nparticle=0;
  // update J and MassMatrix
  for (int nLocalNode=0;nLocalNode<PIC::DomainBlockDecomposition::nLocalBlocks;nLocalNode++) {
      
    cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> * node=PIC::DomainBlockDecomposition::BlockTable[nLocalNode];
    if (_PIC_BC__PERIODIC_MODE_==_PIC_BC__PERIODIC_MODE_ON_) {
      bool BoundaryBlock=false;
      
      for (int iface=0;iface<6;iface++) if (node->GetNeibFace(iface,0,0)==NULL) {
	  //the block is at the domain boundary, and thresefor it is a 'ghost' block that is used to impose the periodic boundary conditions
	  BoundaryBlock=true;
	  break;
	}
      
      if (BoundaryBlock==true) continue;
    }

    if (node->Thread!=PIC::ThisThread) continue;
     
    int nCell[3] = {_BLOCK_CELLS_X_,_BLOCK_CELLS_Y_,_BLOCK_CELLS_Z_};
    
    block=node->block;
    
    memcpy(FirstCellParticleTable,block->FirstCellParticleTable,_BLOCK_CELLS_X_*_BLOCK_CELLS_Y_*_BLOCK_CELLS_Z_*sizeof(long int));
    double CellVolume=1;
    for (int iDim=0; iDim<3;iDim++) CellVolume*=(node->xmax[iDim]-node->xmin[iDim])/nCell[iDim];  //in cgs unit
    
    printf("CellVolume:%e\n",CellVolume);
    for (int k=0;k<_BLOCK_CELLS_Z_;k++) {
      for (int j=0;j<_BLOCK_CELLS_Y_;j++)  {
        for (int i=0;i<_BLOCK_CELLS_X_;i++) {
          ptr=FirstCellParticleTable[i+_BLOCK_CELLS_X_*(j+_BLOCK_CELLS_Y_*k)];
	  
          if (ptr!=-1) {

	    printf("particle, i,j,k,ptr:%d,%d,%d,%ld\n",i,j,k,ptr);
	   
	    //iPar=i;jPar=j;kPar=k;
	    //ParticleNode = node;

	    //  LocalCellNumber=PIC::Mesh::mesh.getCenterNodeLocalNumber(i,j,k);
            //cell=block->GetCenterNode(LocalCellNumber);
	    double vInit[3]={0.0,0.0,0.0},xInit[3]={0.0,0.0,0.0};
	    int spec;
	    double Jg[8][3];
	    for (int ii=0; ii<8; ii++){
	      for (int jj=0; jj<3; jj++){
		Jg[ii][jj]=0.0;
	      }
	    }
	    
	    double * CornerMassMatrixPtr[8];
	    double * CornerJPtr[8]; 
	    char * offset[8];
	    offset[0]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,j,k))->GetAssociatedDataBufferPointer();
	    offset[1]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i+1,j,k))->GetAssociatedDataBufferPointer();
	    offset[2]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i+1,j+1,k))->GetAssociatedDataBufferPointer();
	    offset[3]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,  j+1,k))->GetAssociatedDataBufferPointer();
	    offset[4]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,    j,k+1))->GetAssociatedDataBufferPointer();
	    offset[5]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i+1,  j,k+1))->GetAssociatedDataBufferPointer();
	    offset[6]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i+1,j+1,k+1))->GetAssociatedDataBufferPointer();
	    offset[7]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,  j+1,k+1))->GetAssociatedDataBufferPointer();


	    for (int ii=0; ii<8; ii++) {
	      CornerMassMatrixPtr[ii] = ((double*)offset[ii])+MassMatrixOffsetIndex;
	      CornerJPtr[ii]=((double*)offset[ii])+JxOffsetIndex;
	    }

	    ptrNext=ptr;
	    ParticleDataNext=PIC::ParticleBuffer::GetParticleDataPointer(ptr);
	  
	    while (ptrNext!=-1) {
	      nparticle++;
	      printf("nparticle:%d\n",nparticle);
	      ptr=ptrNext;
	      ParticleData=ParticleDataNext;	  	    
	      memcpy(tempParticleData,ParticleData,PIC::ParticleBuffer::ParticleDataLength);
	      
	      PIC::ParticleBuffer::GetV(vInit,(PIC::ParticleBuffer::byte*)tempParticleData);
	      PIC::ParticleBuffer::GetX(xInit,(PIC::ParticleBuffer::byte*)tempParticleData);
	      spec=PIC::ParticleBuffer::GetI((PIC::ParticleBuffer::byte*)tempParticleData);
	    
	      printf("xInit:%e,%e,%e\n",xInit[0],xInit[1],xInit[2]);
  
	      double temp[3], B[3]={0.0,0.0,0.0};
	      PIC::InterpolationRoutines::CellCentered::cStencil MagneticFieldStencil(false);
	      //interpolate the magnetic field from center nodes to particle location
	      MagneticFieldStencil=*(PIC::InterpolationRoutines::CellCentered::Linear::InitStencil(xInit,node));
	      
	      for (int iStencil=0;iStencil<MagneticFieldStencil.Length;iStencil++) {
		memcpy(temp,MagneticFieldStencil.cell[iStencil]->GetAssociatedDataBufferPointer()+PIC::CPLR::DATAFILE::Offset::MagneticField.RelativeOffset+CurrentBOffset,3*sizeof(double));
		for (int idim=0;idim<3;idim++) B[idim]+=MagneticFieldStencil.Weight[iStencil]*temp[idim];
		
	      }


	      printf("solver B:%e,%e,%e\n",B[0],B[1],B[2]);
	      //convert from SI to cgs
	      for (int idim=0; idim<3; idim++){
		//     B[idim] *= B_SI2cgs;
		//vInit[idim] *= 1e2; 
	      }

	      double QdT_over_m,QdT_over_2m,alpha[3][3],chargeQ;
	      double * WeightPG;
	      double c0,QdT_over_2m_squared;
	      
	      //chargeQ = PIC::MolecularData::GetElectricCharge(spec)*charge_SI2cgs; // in cgs unit
	      chargeQ = PIC::MolecularData::GetElectricCharge(spec)/fabs(PIC::MolecularData::GetElectricCharge(spec));
	      printf("PIC::MolecularData::GetElectricCharge(spec):%e,chargeQ:%e\n",PIC::MolecularData::GetElectricCharge(spec),chargeQ);
	      //	      QdT_over_m=PIC::MolecularData::GetElectricCharge(spec)*dtTotal/PIC::MolecularData::GetMass(spec);
	      //QdT_over_m *=charge_SI2cgs/1e3;// convert from SI to cgs
	      QdT_over_m=chargeQ*dtTotal/1.0;
	      QdT_over_2m=0.5*QdT_over_m;
	      QdT_over_2m_squared=QdT_over_2m*QdT_over_2m;


	      //to calculate alpha, mdv/dt = q(E+v cross B/c)
	      for (int idim=0; idim<3; idim++){
                B[idim] /= LightSpeed; //divided by the speed of light		
              }
	      

	      double BB[3][3],P[3];
	      
	      for (int ii=0;ii<3;ii++) {
		P[ii]=-QdT_over_2m*B[ii];
		
		for (int jj=0;jj<=ii;jj++) {
		  BB[ii][jj]=QdT_over_2m_squared*B[ii]*B[jj];
		  BB[jj][ii]=BB[ii][jj];
		}
	      }

	      c0=1.0/(1.0+QdT_over_2m_squared*(B[0]*B[0]+B[1]*B[1]+B[2]*B[2]));
	      
	      //compute alpha
	      alpha[0][0]=c0*(1.0+BB[0][0]);
	      alpha[0][1]=c0*(-P[2]+BB[0][1]);
	      alpha[0][2]=c0*(P[1]+BB[0][2]);
	      
	      alpha[1][0]=c0*(P[2]+BB[1][0]);
	      alpha[1][1]=c0*(1.0+BB[1][1]);
	      alpha[1][2]=c0*(-P[0]+BB[1][2]);

	      alpha[2][0]=c0*(-P[1]+BB[2][0]);
	      alpha[2][1]=c0*(P[0]+BB[2][1]);
	      alpha[2][2]=c0*(1.0+BB[2][2]);
	      

	      printf("solver:alpha[0]:%e,%e,%e\n",alpha[0][0],alpha[0][1],alpha[0][2]);
	      printf("solver:alpha[1]:%e,%e,%e\n",alpha[1][0],alpha[1][1],alpha[1][2]);
	      printf("solver:alpha[2]:%e,%e,%e\n",alpha[2][0],alpha[2][1],alpha[2][2]);

	      //get weight for each corner
	      // PIC::InterpolationRoutines::CornerBased::cStencil WeightStencil(false);
	      PIC::InterpolationRoutines::CornerBased::InitStencil(xInit,node);
	      
	      double xMinCell[3],xMaxCell[3];
	     
	      xMinCell[0]= node->xmin[0]+(node->xmax[0]-node->xmin[0])/nCell[0]*i;
	      xMinCell[1]= node->xmin[1]+(node->xmax[1]-node->xmin[1])/nCell[1]*j;
	      xMinCell[2]= node->xmin[2]+(node->xmax[2]-node->xmin[2])/nCell[2]*k;
	      
	      xMaxCell[0]=node->xmin[0]+(node->xmax[0]-node->xmin[0])/nCell[0]*(i+1);
	      xMaxCell[1]=node->xmin[1]+(node->xmax[1]-node->xmin[1])/nCell[1]*(j+1);
	      xMaxCell[2]=node->xmin[2]+(node->xmax[2]-node->xmin[2])/nCell[2]*(k+1);
	      
	      WeightPG=PIC::InterpolationRoutines::CornerBased::InterpolationCoefficientTable_LocalNodeOrder;
	      
	      
		for (int iCorner=0; iCorner<8; iCorner++){
		printf("WeightPG[iCorner]:%e\n",WeightPG[iCorner]);
	      }
		/*
		double tempWeight[3][2];
		for (int idim=0;idim<3;idim++){
		  printf("xinit:%e,xmin:%e,xmax:%e\n",xInit[idim],xMinCell[idim],xMaxCell[idim]);
		  tempWeight[idim][1]= (xInit[idim]-xMinCell[idim])/(xMaxCell[idim]-xMinCell[idim]);
		  tempWeight[idim][0]= 1-tempWeight[idim][1];
		  printf("weight1:%e,weight2:%e\n", tempWeight[idim][0],tempWeight[idim][1]);
		}
		
		for (int ii=0;ii<2;ii++){
		  for (int jj=0;jj<2;jj++){
		    for (int kk=0;kk<2;kk++){
		      printf("weight product:%e\n", tempWeight[0][ii]*tempWeight[1][jj]*tempWeight[2][kk]);
		    }
		  }
		}
		*/

		//ParticleEnergy+= 0.5*PIC::MolecularData::GetMass(spec)*1e3*(vInit[0]*vInit[0]+vInit[1]*vInit[1]+vInit[2]*vInit[2]);
		ParticleEnergy += 0.5*1.0*(vInit[0]*vInit[0]+vInit[1]*vInit[1]+vInit[2]*vInit[2]);  
		//compute alpha*vInit
	      double vRot[3]={0.0,0.0,0.0};
	      for (int iDim =0; iDim<3; iDim++){
		for (int jj=0; jj<3; jj++){		  
		  vRot[iDim]+=alpha[iDim][jj]*vInit[jj];
		}
	      }

	      // printf("vRot[iDim]:%e,%e,%e\n",vRot[0],vRot[1],vRot[2]);
	      
	      for (int iCorner=0; iCorner<8; iCorner++){
		for (int iDim=0; iDim<3; iDim++){
		  Jg[iCorner][iDim]+=chargeQ*vRot[iDim]*WeightPG[iCorner];
		  
		  //  printf("Jg[iCorner][iDim]:%e\n",Jg[iCorner][iDim]);
		  
		}
		
	      }

	      for (int iCorner=0; iCorner<8; iCorner++){
		for (int jCorner=0; jCorner<=iCorner; jCorner++){
		  double tempWeightProduct = WeightPG[iCorner]*WeightPG[jCorner]*chargeQ*QdT_over_2m/CellVolume;
		  if (iCorner==jCorner){
		    for (int ii=0; ii<3; ii++){
		      for (int jj=0; jj<3; jj++){		     
			CornerMassMatrixPtr[iCorner][3*ii+jj] += alpha[ii][jj]*tempWeightProduct;
			//printf("CornerMassMatrix:%e\n", *(CornerMassMatrixPtr[iCorner]+3*ii+jj));
		      }
		    }
		  }else{
		    for (int ii=0; ii<3; ii++){
		      for (int jj=0; jj<3; jj++){		     
			double tmp = alpha[ii][jj]*tempWeightProduct;
			CornerMassMatrixPtr[iCorner][9*IndexMatrix[iCorner][jCorner]+3*ii+jj] += tmp;
			CornerMassMatrixPtr[jCorner][9*IndexMatrix[jCorner][iCorner]+3*ii+jj] += tmp;
			//printf("CornerMassMatrix:%e\n",CornerMassMatrixPtr[iCorner][9*IndexMatrix[iCorner][jCorner]+3*ii+jj]);
			//printf("CornerMassMatrix:%e\n",CornerMassMatrixPtr[jCorner][9*IndexMatrix[jCorner][iCorner]+3*ii+jj]);
		      }
		    } 		    
		  }


		}//jCorner
	      }//iCorner
	      
	      ptrNext=PIC::ParticleBuffer::GetNext((PIC::ParticleBuffer::byte*)tempParticleData);

            
	      if (ptrNext!=-1) {
		ParticleDataNext=PIC::ParticleBuffer::GetParticleDataPointer(ptrNext);	      
	      }else{
		//printf("CellVolume2:%e\n",CellVolume);
		for (int iCorner=0; iCorner<8; iCorner++){
		  for (int ii=0; ii<3; ii++){
		     CornerJPtr[iCorner][ii] += (Jg[iCorner][ii])/CellVolume;		     
		  }
		 
		   printf("J at corner %d:%e,%e,%e\n",iCorner, *(CornerJPtr[iCorner]),*(CornerJPtr[iCorner]+1),*(CornerJPtr[iCorner]+2));
		}
	      }

	    }// while (ptrNext!=-1)
	  }//if (ptr!=-1)
	}// for i
      }//for j   
    }//for k
    
  }

 
  MPI_Reduce(&ParticleEnergy, &TotalParticleEnergy, 1, MPI_DOUBLE, MPI_SUM, 0,
	     MPI_GLOBAL_COMMUNICATOR);
  // TotalParticleEnergy *= 1e-7; //in SI
  if (PIC::ThisThread==0) {
    printf("Total Particle Energy:%e\n",TotalParticleEnergy); 
    printf("Total Energy:%.20e,%f\n",TotalParticleEnergy+TotalWaveEnergy,TotalParticleEnergy+TotalWaveEnergy);
    std::cout.precision(20);
    std::cout<<"total energy: "<<TotalParticleEnergy+TotalWaveEnergy<<std::endl;  
  }
}




void UpdateJMassMatrixOld(){
  // update J and MassMatrix 
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM; 
  //the table of cells' particles
  long int FirstCellParticleTable[_BLOCK_CELLS_X_*_BLOCK_CELLS_Y_*_BLOCK_CELLS_Z_];
  PIC::ParticleBuffer::byte *ParticleData,*ParticleDataNext;
  PIC::Mesh::cDataCenterNode *cell;
  PIC::Mesh::cDataBlockAMR *block;
  long int LocalCellNumber,ptr,ptrNext;    
  //temporaty buffer to store the copy of the particle
  char tempParticleData[PIC::ParticleBuffer::ParticleDataLength];
  double ParticleEnergy=0.0;

  //init J and MassMatrix to 0
  for (int nLocalNode=0;nLocalNode<PIC::DomainBlockDecomposition::nLocalBlocks;nLocalNode++) {
      
    cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *node=PIC::DomainBlockDecomposition::BlockTable[nLocalNode];
    if (_PIC_BC__PERIODIC_MODE_==_PIC_BC__PERIODIC_MODE_ON_) {
      bool BoundaryBlock=false;
      
      for (int iface=0;iface<6;iface++) if (node->GetNeibFace(iface,0,0)==NULL) {
	  //the block is at the domain boundary, and thresefor it is a 'ghost' block that is used to impose the periodic boundary conditions
	  BoundaryBlock=true;
	  break;
	}
      
      if (BoundaryBlock==true) continue;
    }

    if (node->Thread!=PIC::ThisThread) continue;
     
    block=node->block;
    
    for (int k=0;k<_BLOCK_CELLS_Z_;k++) {
      for (int j=0;j<_BLOCK_CELLS_Y_;j++)  {
        for (int i=0;i<_BLOCK_CELLS_X_;i++) {
	  char * offset=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,j,k))->GetAssociatedDataBufferPointer();
	  for (int ii=0;ii<3;ii++) *((double*)offset+JxOffsetIndex+ii)=0.0;
	  for (int ii=0;ii<243;ii++) *((double*)offset+MassMatrixOffsetIndex+ii)=0.0;
	}
      }
    }
  }

  // update J and MassMatrix
  for (int nLocalNode=0;nLocalNode<PIC::DomainBlockDecomposition::nLocalBlocks;nLocalNode++) {
      
    cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> * node=PIC::DomainBlockDecomposition::BlockTable[nLocalNode];
    if (_PIC_BC__PERIODIC_MODE_==_PIC_BC__PERIODIC_MODE_ON_) {
      bool BoundaryBlock=false;
      
      for (int iface=0;iface<6;iface++) if (node->GetNeibFace(iface,0,0)==NULL) {
	  //the block is at the domain boundary, and thresefor it is a 'ghost' block that is used to impose the periodic boundary conditions
	  BoundaryBlock=true;
	  break;
	}
      
      if (BoundaryBlock==true) continue;
    }

    if (node->Thread!=PIC::ThisThread) continue;
     
    int nCell[3] = {_BLOCK_CELLS_X_,_BLOCK_CELLS_Y_,_BLOCK_CELLS_Z_};
    
    block=node->block;
    
    memcpy(FirstCellParticleTable,block->FirstCellParticleTable,_BLOCK_CELLS_X_*_BLOCK_CELLS_Y_*_BLOCK_CELLS_Z_*sizeof(long int));
    double CellVolume=1;
    for (int iDim=0; iDim<3;iDim++) CellVolume*=(node->xmax[iDim]-node->xmin[iDim])/nCell[iDim]*1e2;  //in cgs unit
    
    for (int k=0;k<_BLOCK_CELLS_Z_;k++) {
      for (int j=0;j<_BLOCK_CELLS_Y_;j++)  {
        for (int i=0;i<_BLOCK_CELLS_X_;i++) {
          ptr=FirstCellParticleTable[i+_BLOCK_CELLS_X_*(j+_BLOCK_CELLS_Y_*k)];
	  
          if (ptr!=-1) {
	    //  LocalCellNumber=PIC::Mesh::mesh.getCenterNodeLocalNumber(i,j,k);
            //cell=block->GetCenterNode(LocalCellNumber);
	    double vInit[3]={0.0,0.0,0.0},xInit[3]={0.0,0.0,0.0};
	    int spec;
	    double Jg[8][3];
	    for (int ii=0; ii<8; ii++){
	      for (int jj=0; jj<3; jj++){
		Jg[ii][jj]=0.0;
	      }
	    }
	    
	    double * CornerMassMatrixPtr[8],* CornerJPtr[8]; 
	    char * offset[8];
	    offset[0]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,j,k))->GetAssociatedDataBufferPointer();
	    offset[1]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i+1,j,k))->GetAssociatedDataBufferPointer();
	    offset[2]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i+1,j+1,k))->GetAssociatedDataBufferPointer();
	    offset[3]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,  j+1,k))->GetAssociatedDataBufferPointer();
	    offset[4]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,    j,k+1))->GetAssociatedDataBufferPointer();
	    offset[5]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i+1,  j,k+1))->GetAssociatedDataBufferPointer();
	    offset[6]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i+1,j+1,k+1))->GetAssociatedDataBufferPointer();
	    offset[7]=block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,  j+1,k+1))->GetAssociatedDataBufferPointer();


	    for (int ii=0; ii<8; ii++) {
	      CornerMassMatrixPtr[ii] = ((double*)offset[ii])+MassMatrixOffsetIndex;
	      CornerJPtr[ii]=((double*)offset[ii])+JxOffsetIndex;
	    }

	    ptrNext=ptr;
	    ParticleDataNext=PIC::ParticleBuffer::GetParticleDataPointer(ptr);
	  
	    while (ptrNext!=-1) {
	      ptr=ptrNext;
	      ParticleData=ParticleDataNext;	  	    
	      memcpy((void*)tempParticleData,(void*)ParticleData,PIC::ParticleBuffer::ParticleDataLength);
	      
	      PIC::ParticleBuffer::GetV(vInit,(PIC::ParticleBuffer::byte*)tempParticleData);
	      PIC::ParticleBuffer::GetX(xInit,(PIC::ParticleBuffer::byte*)tempParticleData);
	      spec=PIC::ParticleBuffer::GetI((PIC::ParticleBuffer::byte*)tempParticleData);
	      
  
	      double temp[3], B[3];
	      PIC::InterpolationRoutines::CellCentered::cStencil MagneticFieldStencil(false);
	      //interpolate the magnetic field from center nodes to particle location
	      MagneticFieldStencil=*(PIC::InterpolationRoutines::CellCentered::Linear::InitStencil(xInit,node));
	      
	      for (int iStencil=0;iStencil<MagneticFieldStencil.Length;iStencil++) {
		memcpy(temp,MagneticFieldStencil.cell[iStencil]->GetAssociatedDataBufferPointer()+PIC::CPLR::DATAFILE::Offset::MagneticField.RelativeOffset,3*sizeof(double));
		for (int idim=0;idim<3;idim++) B[idim]+=MagneticFieldStencil.Weight[iStencil]*temp[idim];
	      }
	      //convert from SI to cgs
	      for (int idim=0; idim<3; idim++){
		B[idim] *= B_SI2cgs;
		vInit[idim] *= 1e2; 
	      }

	      double QdT_over_m,QdT_over_2m,alpha[3][3],chargeQ;
	      double * WeightPG;
	      double c0,QdT_over_2m_squared;
	      
	      chargeQ = PIC::MolecularData::GetElectricCharge(spec)*3e9; // in cgs unit
	      QdT_over_m=PIC::MolecularData::GetElectricCharge(spec)*dtTotal/PIC::MolecularData::GetMass(spec);
	      QdT_over_m *=3e9/1e3;// convert from SI to cgs
	      QdT_over_2m=0.5*QdT_over_m;
	      QdT_over_2m_squared=QdT_over_2m*QdT_over_2m;

	      double BB[3][3],P[3];
	      
	      for (i=0;i<3;i++) {
		P[i]=-QdT_over_2m*B[i];
		
		for (j=0;j<=i;j++) {
		  BB[i][j]=QdT_over_2m_squared*B[i]*B[j];
		  BB[j][i]=BB[i][j];
		}
	      }

	      c0=1.0/(1.0+QdT_over_2m_squared*(B[0]*B[0]+B[1]*B[1]+B[2]*B[2]));
	      
	      //compute alpha
	      alpha[0][0]=c0*(1.0+BB[0][0]);
	      alpha[0][1]=c0*(-P[2]+BB[0][1]);
	      alpha[0][2]=c0*(P[1]+BB[0][2]);
	      
	      alpha[1][0]=c0*(P[2]+BB[1][0]);
	      alpha[1][1]=c0*(1.0+BB[1][1]);
	      alpha[1][2]=c0*(-P[0]+BB[1][2]);

	      alpha[2][0]=c0*(-P[1]+BB[2][0]);
	      alpha[2][1]=c0*(P[0]+BB[2][1]);
	      alpha[2][2]=c0*(1.0+BB[2][2]);
	      
	      //get weight for each corner
	      // PIC::InterpolationRoutines::CornerBased::cStencil WeightStencil(false);
	      PIC::InterpolationRoutines::CellCentered::Linear::InitStencil(xInit,node);
	      WeightPG=PIC::InterpolationRoutines::CornerBased::InterpolationCoefficientTable_LocalNodeOrder;

	      ParticleEnergy = 0.5*PIC::MolecularData::GetMass(spec)*1e3*(vInit[0]*vInit[0]+vInit[1]*vInit[1]+vInit[2]*vInit[2]);
	      //compute alpha*vInit
	      double vRot[3]={0.0,0.0,0.0}, vTemp[3]={0.0,0.0,0.0};
	      for (int iDim =0; iDim<3; iDim++){
		for (int jj=0; jj<3; jj++){		  
		  vRot[iDim]+=alpha[iDim][jj]*vInit[jj];
		}
	      }

	      for (int iCorner=0; iCorner<8; iCorner++){
		for (int iDim=0; iDim<3; iDim++){
		  Jg[iCorner][iDim]+=chargeQ*vRot[iDim]*WeightPG[iCorner];
		}
	      }

	      for (int iCorner=0; iCorner<8; iCorner++){
		for (int jCorner=0; jCorner<=iCorner; jCorner++){
		  double tempWeightProduct = WeightPG[iCorner]*WeightPG[jCorner]*chargeQ*QdT_over_2m/CellVolume;
		  if (iCorner==jCorner){
		    for (int ii=0; ii<3; ii++){
		      for (int jj=0; jj<3; jj++){		     
			*(CornerMassMatrixPtr[iCorner]+3*ii+jj) += alpha[ii][jj]*tempWeightProduct;
		      }
		    }
		  }else{
		    for (int ii=0; ii<3; ii++){
		      for (int jj=0; jj<3; jj++){		     
			double tmp = alpha[ii][jj]*tempWeightProduct;
			*(CornerMassMatrixPtr[iCorner]+9*IndexMatrix[iCorner][jCorner]+3*ii+jj) += tmp;
			*(CornerMassMatrixPtr[jCorner]+9*IndexMatrix[jCorner][iCorner]+3*ii+jj) += tmp;
		      }
		    } 		    
		  }


		}//jCorner
	      }//iCorner
	      
	      ptrNext=PIC::ParticleBuffer::GetNext((PIC::ParticleBuffer::byte*)tempParticleData);

            
	      if (ptrNext!=-1) {
		ParticleDataNext=PIC::ParticleBuffer::GetParticleDataPointer(ptrNext);	      
	      }else{
		for (int iCorner=0; iCorner<8; iCorner++){
		  for (int ii=0; ii<3; ii++){
		    *(CornerJPtr[iCorner]+ii) += Jg[iCorner][ii];
		  }
		}
	      }

	    }// while (ptrNext!=-1)
	  }//if (ptr!=-1)
	}// for i
      }//for j   
    }//for k
    
  }

 
  MPI_Reduce(&ParticleEnergy, &TotalParticleEnergy, 1, MPI_DOUBLE, MPI_SUM, 0,
	     MPI_GLOBAL_COMMUNICATOR);
  if (PIC::ThisThread==0) printf("Total Particle Energy:%f\n",TotalParticleEnergy);


}

//void UpdateBWrong(){ 
void PIC::FieldSolver::Electromagnetic::ECSIM::UpdateB(){
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;  
  
  //compute B^(n+1) from B^(n) and E^(n+theta)
  for (int nLocalNode=0;nLocalNode<PIC::DomainBlockDecomposition::nLocalBlocks;nLocalNode++) {
      
    cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *node=PIC::DomainBlockDecomposition::BlockTable[nLocalNode];
    if (_PIC_BC__PERIODIC_MODE_==_PIC_BC__PERIODIC_MODE_ON_) {
      bool BoundaryBlock=false;
      
      for (int iface=0;iface<6;iface++) if (node->GetNeibFace(iface,0,0)==NULL) {
        //the block is at the domain boundary, and thresefor it is a 'ghost' block that is used to impose the periodic boundary conditions
	  BoundaryBlock=true;
	  break;
	}
      
      if (BoundaryBlock==true) continue;
    }
    
    if (node->Thread!=PIC::ThisThread) continue;
     
    int nCell[3] = {_BLOCK_CELLS_X_,_BLOCK_CELLS_Y_,_BLOCK_CELLS_Z_};
    double dx[3],coeff[3],coeff4[3],x[3]; 
    for (int iDim=0; iDim<3; iDim++){
      dx[iDim]=(node->xmax[iDim]-node->xmin[iDim])/nCell[iDim];
      //convert to cgs
      //dx[iDim]*=1e2;

      //coeff[iDim] = cLight*dt/dx[iDim];
      coeff[iDim] = cDt/dx[iDim];
      coeff4[iDim] = coeff[iDim]*0.25; //coefficients for curl calculation
    }
    
    for (int k=0;k<_BLOCK_CELLS_Z_;k++) for (int j=0;j<_BLOCK_CELLS_Y_;j++) for (int i=0;i<_BLOCK_CELLS_X_;i++) {
	  char * offset;
	  double Ex[2][2][2], Ey[2][2][2], Ez[2][2][2];
	  int index[3]={i,j,k};
	  for (int iDim=0; iDim<3; iDim++){
	    x[iDim]=node->xmin[iDim]+(index[iDim]+0.5)*dx[iDim]/1e2;	   
	  }

	  for (int kk=0;kk<2;kk++) for (int jj=0;jj<2;jj++) for (int ii=0;ii<2;ii++){
		offset=node->block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i+ii,j+jj,k+kk))->GetAssociatedDataBufferPointer();
		double * ptr =  (double*)(offset+OffsetE_HalfTimeStep);
		Ex[ii][jj][kk]=ptr[ExOffsetIndex];//*E_SI2cgs;
		Ey[ii][jj][kk]=ptr[EyOffsetIndex];//*E_SI2cgs;
		Ez[ii][jj][kk]=ptr[EzOffsetIndex];//*E_SI2cgs;
	      }
	    
	    offset=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i,j,k))->GetAssociatedDataBufferPointer();
	    
	    double * CurrentPtr = (double*)(offset+CurrentBOffset);
	    double * PrevPtr = (double*)(offset+PrevBOffset);
	    //store next B at prevptr
	    double tempB[3]={0.0,0.0,0.0};
	    /*
	    PrevPtr[BxOffsetIndex] = CurrentPtr[BxOffsetIndex];
	    PrevPtr[ByOffsetIndex] = CurrentPtr[ByOffsetIndex];
	    PrevPtr[BzOffsetIndex] = CurrentPtr[BzOffsetIndex];
	    */

	    for (int ii=0;ii<2;ii++){ 
	      for (int jj=0; jj<2;jj++){
		tempB[BxOffsetIndex] += (-coeff4[1]*(Ez[ii][1][jj]-Ez[ii][0][jj])+coeff4[2]*(Ey[ii][jj][1]-Ey[ii][jj][0]));///B_SI2cgs;
		tempB[ByOffsetIndex] += (-coeff4[2]*(Ex[ii][jj][1]-Ex[ii][jj][0])+coeff4[0]*(Ez[1][ii][jj]-Ez[0][ii][jj]));///B_SI2cgs;
		tempB[BzOffsetIndex] += (-coeff4[0]*(Ey[1][ii][jj]-Ey[0][ii][jj])+coeff4[1]*(Ex[ii][1][jj]-Ex[ii][0][jj]));///B_SI2cgs;		
	      }
	    }

	    PrevPtr[BxOffsetIndex] = CurrentPtr[BxOffsetIndex]+tempB[BxOffsetIndex];
	    PrevPtr[ByOffsetIndex] = CurrentPtr[ByOffsetIndex]+tempB[ByOffsetIndex];
	    PrevPtr[BzOffsetIndex] = CurrentPtr[BzOffsetIndex]+tempB[BzOffsetIndex];
	    /*
	    for (int ii=0;ii<2;ii++){ 
	      for (int jj=0; jj<2;jj++){
		CurrentPtr[BxOffsetIndex] += (-coeff4[1]*(Ez[ii][1][jj]-Ez[ii][0][jj])+coeff4[2]*(Ey[ii][jj][1]-Ey[ii][jj][0]));///B_SI2cgs;
		CurrentPtr[ByOffsetIndex] += (-coeff4[2]*(Ex[ii][jj][1]-Ex[ii][jj][0])+coeff4[0]*(Ez[1][ii][jj]-Ez[0][ii][jj]));///B_SI2cgs;
		CurrentPtr[BzOffsetIndex] += (-coeff4[0]*(Ey[1][ii][jj]-Ey[0][ii][jj])+coeff4[1]*(Ex[ii][1][jj]-Ex[ii][0][jj]));///B_SI2cgs;		
	      }
	    }
	    */


	}
  }


   //swap current and prev pointer

  
  int tempInt;
  tempInt=PrevBOffset;
  PrevBOffset=CurrentBOffset;
  CurrentBOffset=tempInt;
  printf("Update B:%d,%d",CurrentBOffset,PrevBOffset);
 

    switch (_PIC_BC__PERIODIC_MODE_) {
    case _PIC_BC__PERIODIC_MODE_OFF_:
      PIC::Mesh::mesh.ParallelBlockDataExchange();
      break;
      
    case _PIC_BC__PERIODIC_MODE_ON_:
      PIC::BC::ExternalBoundary::Periodic::UpdateData();
      break;
    } 
}




//void PIC::FieldSolver::Electromagnetic::ECSIM::UpdateB(){
 void UpdateBOrigin(){
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;    
  //compute B^(n+1) from B^(n) and E^(n+theta)
  for (int nLocalNode=0;nLocalNode<PIC::DomainBlockDecomposition::nLocalBlocks;nLocalNode++) {
      
    cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *node=PIC::DomainBlockDecomposition::BlockTable[nLocalNode];
    if (_PIC_BC__PERIODIC_MODE_==_PIC_BC__PERIODIC_MODE_ON_) {
      bool BoundaryBlock=false;
      
      for (int iface=0;iface<6;iface++) if (node->GetNeibFace(iface,0,0)==NULL) {
        //the block is at the domain boundary, and thresefor it is a 'ghost' block that is used to impose the periodic boundary conditions
	  BoundaryBlock=true;
	  break;
	}
      
      if (BoundaryBlock==true) continue;
    }
    
    if (node->Thread!=PIC::ThisThread) continue;
     
    int nCell[3] = {_BLOCK_CELLS_X_,_BLOCK_CELLS_Y_,_BLOCK_CELLS_Z_};
    double dx[3],coeff[3],coeff4[3]; 
    for (int iDim=0; iDim<3; iDim++){
      dx[iDim]=(node->xmax[iDim]-node->xmin[iDim])/nCell[iDim];
      
      //coeff[iDim] = cLight*dt/dx[iDim];
      coeff[iDim] = cDt/dx[iDim];
      coeff4[iDim] = coeff[iDim]*0.25; //coefficients for curl calculation
    }
    
    for (int k=0;k<_BLOCK_CELLS_Z_;k++) for (int j=0;j<_BLOCK_CELLS_Y_;j++) for (int i=0;i<_BLOCK_CELLS_X_;i++) {
	  char * offset;
	  double Ex[2][2][2], Ey[2][2][2], Ez[2][2][2];
	  for (int kk=0;kk<2;kk++) for (int jj=0;jj<2;jj++) for (int ii=0;ii<2;ii++){
		offset=node->block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i+ii,j+jj,k+kk))->GetAssociatedDataBufferPointer();
		double * ptr =  (double*)(offset+OffsetE_HalfTimeStep);
		Ex[ii][jj][kk]=ptr[ExOffsetIndex];//*E_SI2cgs;
		Ey[ii][jj][kk]=ptr[EyOffsetIndex];//*E_SI2cgs;
		Ez[ii][jj][kk]=ptr[EzOffsetIndex];//*E_SI2cgs;
	      }
	    
	    offset=node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i,j,k))->GetAssociatedDataBufferPointer();
	    double * CurrentPtr = (double*)(offset+CurrentBOffset);
		    
	   	   	   	   
	    for (int ii=0;ii<2;ii++){ 
	      for (int jj=0; jj<2;jj++){
		CurrentPtr[BxOffsetIndex] += (-coeff4[1]*(Ez[ii][1][jj]-Ez[ii][0][jj])+coeff4[2]*(Ey[ii][jj][1]-Ey[ii][jj][0]));///B_SI2cgs;
		CurrentPtr[ByOffsetIndex] += (-coeff4[2]*(Ex[ii][jj][1]-Ex[ii][jj][0])+coeff4[0]*(Ez[1][ii][jj]-Ez[0][ii][jj]));///B_SI2cgs;
		CurrentPtr[BzOffsetIndex] += (-coeff4[0]*(Ey[1][ii][jj]-Ey[0][ii][jj])+coeff4[1]*(Ex[ii][1][jj]-Ex[ii][0][jj]));///B_SI2cgs;
		
	      }
	    }
	  	  
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
}


void PIC::FieldSolver::Electromagnetic::ECSIM::UpdateE(){
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;    
  //compute E^(n+1)  from E^(n+theta) and E^n
  
  double WaveEnergySum =0.0;

  for (int nLocalNode=0;nLocalNode<PIC::DomainBlockDecomposition::nLocalBlocks;nLocalNode++) {
    
    cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *node=PIC::DomainBlockDecomposition::BlockTable[nLocalNode];
    if (_PIC_BC__PERIODIC_MODE_==_PIC_BC__PERIODIC_MODE_ON_) {
      bool BoundaryBlock=false;
      
      for (int iface=0;iface<6;iface++) if (node->GetNeibFace(iface,0,0)==NULL) {
	  //the block is at the domain boundary, and thresefor it is a 'ghost' block that is used to impose the periodic boundary conditions
	  BoundaryBlock=true;
	  break;
	}
      
      if (BoundaryBlock==true) continue;
    }
      
    if (node->Thread!=PIC::ThisThread) continue;
    
    double CellVolume=1.0;
    int nCell[3] = {_BLOCK_CELLS_X_,_BLOCK_CELLS_Y_,_BLOCK_CELLS_Z_};
    for (int iDim=0; iDim<3;iDim++) CellVolume*=(node->xmax[iDim]-node->xmin[iDim])/nCell[iDim]; 
    
    for (int k=0;k<_BLOCK_CELLS_Z_;k++) for (int j=0;j<_BLOCK_CELLS_Y_;j++) for (int i=0;i<_BLOCK_CELLS_X_;i++) { //?some doubts
	  char * offset;
	  
	  offset=node->block->GetCornerNode(PIC::Mesh::mesh.getCornerNodeLocalNumber(i,j,k))->GetAssociatedDataBufferPointer();
	  char * centerOffset =node->block->GetCenterNode(PIC::Mesh::mesh.getCenterNodeLocalNumber(i,j,k))->GetAssociatedDataBufferPointer();
	  double Bx0,By0,Bz0;
	  double * CurrentB_Ptr =  (double*)(centerOffset+CurrentBOffset);
	  double * HalfStepPtr = (double*)(offset+OffsetE_HalfTimeStep);
	  double * CurrentPtr = (double*)(offset+CurrentEOffset);
	  double Ex,Ey,Ez;
	  
	  // in SI unit
	  Ex = (HalfStepPtr[ExOffsetIndex]-(1.0-theta)*CurrentPtr[ExOffsetIndex])/theta;
	  Ey = (HalfStepPtr[EyOffsetIndex]-(1.0-theta)*CurrentPtr[EyOffsetIndex])/theta;
	  Ez = (HalfStepPtr[EzOffsetIndex]-(1.0-theta)*CurrentPtr[EzOffsetIndex])/theta;
	  
	  CurrentPtr[ExOffsetIndex] = Ex;
	  CurrentPtr[EyOffsetIndex] = Ey;
	  CurrentPtr[EzOffsetIndex] = Ez;
	  
	  Bx0=CurrentB_Ptr[BxOffsetIndex];
	  By0=CurrentB_Ptr[ByOffsetIndex];
	  Bz0=CurrentB_Ptr[BzOffsetIndex]; 
	  WaveEnergySum += ((Ex*Ex+Ey*Ey+Ez*Ez)+(Bx0*Bx0+By0*By0+Bz0*Bz0))*0.125/Pi*CellVolume;
	  //WaveEnergySum += (Ex*Ex+Ey*Ey+Ez*Ez)+(Bx0*Bx0+By0*By0+Bz0*Bz0); //for Gaussian 
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
 
  MPI_Reduce(&WaveEnergySum, &TotalWaveEnergy, 1, MPI_DOUBLE, MPI_SUM, 0,
	     MPI_GLOBAL_COMMUNICATOR);
  if (PIC::ThisThread==0) {
    printf("Total Wave Energy:%f\n",TotalWaveEnergy);
    // printf("Total Energy:%f\n",TotalParticleEnergy+TotalWaveEnergy);
  }
  
}
 

void PIC::FieldSolver::Electromagnetic::ECSIM::UpdateMatrixElement(cLinearSystemCornerNode<PIC::Mesh::cDataCornerNode,3,81,82,16,1,1>::cMatrixRow* row){
  double fourPiDtTheta=4*Pi*dtTotal*theta;
  for (int iElement=0; iElement<row->nNonZeroElements;iElement++){
    cLinearSystemCornerNode<PIC::Mesh::cDataCornerNode,3,81,82,16,1,1>::cStencilElement* el=row->Elements+iElement;
    el->MatrixElementValue=el->MatrixElementParameterTable[0];
    el->MatrixElementValue+=*((double *)el->MatrixElementSupportTable[0])*fourPiDtTheta;
    
    //printf("iElement:%d,const:%f,matrixvalue:%f\n",iElement,el->MatrixElementParameterTable[0],el->MatrixElementValue);
  }  
  
}
 

 //update the RHS vector
double PIC::FieldSolver::Electromagnetic::ECSIM::UpdateRhs(int iVar,
			      cLinearSystemCornerNode<PIC::Mesh::cDataCornerNode,3,81,82,16,1,1>::cRhsSupportTable* RhsSupportTable_CornerNodes,int RhsSupportLength_CornerNodes,
			      cLinearSystemCornerNode<PIC::Mesh::cDataCornerNode,3,81,82,16,1,1>::cRhsSupportTable* RhsSupportTable_CenterNodes,int RhsSupportLength_CenterNodes) {
    int i;
    double res=0.0;

    using namespace PIC::FieldSolver::Electromagnetic::ECSIM;    
    double fourPiDtTheta=4*Pi*dtTotal*theta; 
   
 

    for (int ii=0;ii<27;ii++) {
      double * tempPtr = (double*)(RhsSupportTable_CornerNodes[ii].AssociatedDataPointer+CurrentEOffset);
      res+=(tempPtr[ExOffsetIndex]*RhsSupportTable_CornerNodes[ii].Coefficient+
	    tempPtr[EyOffsetIndex]*RhsSupportTable_CornerNodes[ii+27].Coefficient+
	    tempPtr[EzOffsetIndex]*RhsSupportTable_CornerNodes[ii+54].Coefficient);//*E_SI2cgs;
				}

    double * tempMassMatrixPtr = ((double*)RhsSupportTable_CornerNodes[0].AssociatedDataPointer)+MassMatrixOffsetIndex;
    
    //mass matrix part
    for (int ii=0;ii<27;ii++) {
      double * tempPtr = (double*)(RhsSupportTable_CornerNodes[ii].AssociatedDataPointer+CurrentEOffset);
      res+=(tempPtr[ExOffsetIndex]*tempMassMatrixPtr[MassMatrixOffsetTable[iVar][ii]]+
	tempPtr[EyOffsetIndex]*tempMassMatrixPtr[MassMatrixOffsetTable[iVar][ii+27]]+
	    tempPtr[EzOffsetIndex]*tempMassMatrixPtr[MassMatrixOffsetTable[iVar][ii+54]])*(-fourPiDtTheta);//*E_SI2cgs
    }
    
    
    // current effect
    res+=((double*)(RhsSupportTable_CornerNodes[81].AssociatedDataPointer))[JxOffsetIndex+iVar]*
      RhsSupportTable_CornerNodes[81].Coefficient;
    

    /*
    //contribution from corner nodes
    if (_CURRENT_MODE_==_PIC_MODE_OFF_) for (i=0;i<RhsSupportLength_CornerNodes;i++) {
	res+=((double*)(RhsSupportTable_CornerNodes[i].AssociatedDataPointer+CurrentCornerNodeOffset))[iVar]*RhsSupportTable_CornerNodes[i].Coefficient;
      }

    if (_CURRENT_MODE_==_PIC_MODE_ON_) {
      //no.0-no.6
      for (i=0;i<7;i++) res+=((double*)(RhsSupportTable_CornerNodes[i].AssociatedDataPointer+CurrentCornerNodeOffset))[iVar]*RhsSupportTable_CornerNodes[i].Coefficient;
      //no.7
      res+=((double*)(RhsSupportTable_CornerNodes[i].AssociatedDataPointer+CurrentCornerNodeOffset))[iVar+JxOffsetIndex]*RhsSupportTable_CornerNodes[i].Coefficient;

      //Ex:Ey,Ey:Ez,Ez:Ex iVarNext
      for (i=8;i<12;i++) res+=((double*)(RhsSupportTable_CornerNodes[i].AssociatedDataPointer+CurrentCornerNodeOffset))[(iVar+4)%3]*RhsSupportTable_CornerNodes[i].Coefficient;
      
      //Ex:Ez,Ey:Ex,Ez:Ey iVarPrev
      for (i=12;i<16;i++) res+=((double*)(RhsSupportTable_CornerNodes[i].AssociatedDataPointer+CurrentCornerNodeOffset))[(iVar+2)%3]*RhsSupportTable_CornerNodes[i].Coefficient;
      
      
    }
    
    */


    //contribution from center nodes
    for (i=0; i<8;i++){
      res+=((double*)(RhsSupportTable_CenterNodes[i].AssociatedDataPointer+CurrentBOffset))[(iVar+2)%3]*RhsSupportTable_CenterNodes[i].Coefficient;//*B_SI2cgs;
    }//E=iVar,B=((iVar+2)%3) Ex:Bz, Ey:Bx, Ez:By
    
    for (i=8; i<16;i++){
      res+=((double*)(RhsSupportTable_CenterNodes[i].AssociatedDataPointer+CurrentBOffset))[(iVar+4)%3]*RhsSupportTable_CenterNodes[i].Coefficient;//*B_SI2cgs;
    }//E=iVar,B=((iVar+4)%3)  Ex:By, Ey:Bz, Ez:Bx
    
    //if (fabs(res)>1e-3) printf("rhs:%f\n",res);

    return res;
    }





void PIC::FieldSolver::Electromagnetic::ECSIM::BuildMatrix() {
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;    
  Solver.Reset();
  Solver.BuildMatrix(GetStencil);
}


void PIC::FieldSolver::Electromagnetic::ECSIM::TimeStep() {
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;    
   
  UpdateJMassMatrix(); 
  Solver.UpdateRhs(UpdateRhs); 
  Solver.UpdateMatrixNonZeroCoefficients(UpdateMatrixElement);
   
  linear_solver_matvec_c = matvec;
  Solver.Solve(SetInitialGuess,ProcessFinalSolution,1e-15,200);
  UpdateB();
  UpdateE();
   
 }


//set the initial guess
void PIC::FieldSolver::Electromagnetic::ECSIM::SetInitialGuess(double* x,PIC::Mesh::cDataCornerNode* CornerNode) {
  //  x[0]=*((double*)(CornerNode->GetAssociatedDataBufferPointer()+CurrentCornerNodeOffset));
  x[0]=0.0;
  x[1]=0.0;
  x[2]=0.0;
}

//process the solution vector
void PIC::FieldSolver::Electromagnetic::ECSIM::ProcessFinalSolution(double* x,PIC::Mesh::cDataCornerNode* CornerNode) {
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;    
  char *offset=CornerNode->GetAssociatedDataBufferPointer();
  //in SI unit
  /*
  ((double*)(offset+OffsetE_HalfTimeStep))[0] =x[0]/E_SI2cgs+((double*)(offset+CurrentEOffset))[0];
  ((double*)(offset+OffsetE_HalfTimeStep))[1] =x[1]/E_SI2cgs+((double*)(offset+CurrentEOffset))[1];
  ((double*)(offset+OffsetE_HalfTimeStep))[2] =x[2]/E_SI2cgs+((double*)(offset+CurrentEOffset))[2];
  */
  ((double*)(offset+OffsetE_HalfTimeStep))[0] =x[0]+((double*)(offset+CurrentEOffset))[0];
  ((double*)(offset+OffsetE_HalfTimeStep))[1] =x[1]+((double*)(offset+CurrentEOffset))[1];
  ((double*)(offset+OffsetE_HalfTimeStep))[2] =x[2]+((double*)(offset+CurrentEOffset))[2];

}


void PIC::FieldSolver::Electromagnetic::ECSIM::output::PrintCenterNodeVariableList(FILE* fout,int DataSetNumber) {
  fprintf(fout,",\"Bx (center node)\",\"By (center node)\",\"Bz (center node)\"");
}

void PIC::FieldSolver::Electromagnetic::ECSIM::output::InterpolateCenterNode(PIC::Mesh::cDataCenterNode** InterpolationList,double *InterpolationCoeficients,int nInterpolationCoeficients,PIC::Mesh::cDataCenterNode *CenterNode) {

  double Wave[3];
  int i,iDim;
  char *SamplingBuffer;
  
  for (iDim =0;iDim<3; iDim++) Wave[iDim]=0.0;

  for (i=0;i<nInterpolationCoeficients;i++) {
    SamplingBuffer=InterpolationList[i]->GetAssociatedDataBufferPointer();
    Wave[0] += (((double*)SamplingBuffer)[0])*InterpolationCoeficients[i];
    Wave[1] += (((double*)SamplingBuffer)[1])*InterpolationCoeficients[i];
    Wave[2] += (((double*)SamplingBuffer)[2])*InterpolationCoeficients[i];
  }

  memcpy(CenterNode->GetAssociatedDataBufferPointer(),Wave,3*sizeof(double));

}

void PIC::FieldSolver::Electromagnetic::ECSIM::output::PrintCenterNodeData(FILE* fout,int DataSetNumber,CMPI_channel *pipe,int CenterNodeThread,PIC::Mesh::cDataCenterNode *CenterNode) {
  int idim;
  double * t;

  if (pipe->ThisThread==CenterNodeThread) {
    t= (double*)(CenterNode->GetAssociatedDataBufferPointer());
  }
  
  if (pipe->ThisThread==0) {
    if (CenterNodeThread!=0) t=pipe->recvPointer<double>(3,CenterNodeThread);
    fprintf(fout,"%e %e %e ",t[0],t[1],t[2]);
  }
  else pipe->send(t,3);

}

void PIC::FieldSolver::Electromagnetic::ECSIM::output::PrintCornerNodeVariableList(FILE* fout,int DataSetNumber) {
  fprintf(fout,",\"Ex (corner node)\",\"Ey (corner node)\",\"Ez (corner node)\"");
}

void PIC::FieldSolver::Electromagnetic::ECSIM::output::PrintCornerNodeData(FILE* fout,int DataSetNumber,CMPI_channel *pipe,int CornerNodeThread,PIC::Mesh::cDataCornerNode *CornerNode) {
  int idim;
  double * t;
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;    

  if (pipe->ThisThread==CornerNodeThread) {
    t= ((double*)(CornerNode->GetAssociatedDataBufferPointer()+CurrentEOffset));
  }

  if (pipe->ThisThread==0) {
    if (CornerNodeThread!=0) t=pipe->recvPointer<double>(3,CornerNodeThread);
    fprintf(fout,"%e %e %e ",t[0],t[1],t[2]);
  }
  else pipe->send(t,3);
}

void PIC::FieldSolver::Electromagnetic::ECSIM::matvec(double* VecIn, double * VecOut, int n){
  using namespace PIC::FieldSolver::Electromagnetic::ECSIM;
  Solver.MultiplyVector(VecOut,VecIn,n);
}
