//$Id$


#include "pic.h"
#include "Exosphere.dfn"
#include "Exosphere.h"

PIC::Mesh::cDatumWeighted PIC::Mover::GuidingCenter::Sampling::DatumTotalKineticEnergy(1,"\"Total kinetic energy [J]\"", true);

void PIC::Mover::GuidingCenter::Sampling::SampleParticleData(char* ParticleData, double LocalParticleWeight, char* SamplingBuffer, int spec) {

  //compute total kinetic energy for the given particle
  // V^2 = Vguide_paral^2 + (Vguide_perp+Vgyr)^2
  //     = Vguide_paral^2 + Vguide_perp^2 + Vgyr^2 + 2 Vguide_perp * Vgyr
  // <Vguide_perp * Vgyr> = 0
  // Vgyr is derived from magnetic moment
  // \mu=p_{paral}^2/(2 m0 B)
  double KinEnergy=0;
  double m0=PIC::MolecularData::GetMass(spec); 
  //guiding center motion
  double Vguide[3]={0.0,0.0,0.0};
  
  //the function can be executed only the the offset for the particle magnetic moment is defined
  if (_PIC_PARTICLE_DATA__MAGNETIC_MOMENT_OFFSET_!=-1) {
    PIC::ParticleBuffer::GetV(Vguide,(PIC::ParticleBuffer::byte*)ParticleData);

    #if _PIC_PARTICLE_MOVER__RELATIVITY_MODE_ == _PIC_MODE_ON_
    exit(__LINE__,__FILE__,"ERROR:not implemented");
    #else
    KinEnergy+=0.5*m0*(Vguide[0]*Vguide[0]+Vguide[1]*Vguide[1]+Vguide[2]*Vguide[2]);
    #endif //_PIC_PARTICLE_MOVER__RELATIVITY_MODE_ == _PIC_MODE_ON_

    //gyration energy
    //magnetic moment
    double mu= PIC::ParticleBuffer::GetMagneticMoment((PIC::ParticleBuffer::byte*)ParticleData);
    // also get the magnetic field at particle location
    double AbsB=0,x[3]={0.0,0.0,0.0},B[3]={0.0,0.0,0.0};
    static cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *node=NULL;

    PIC::ParticleBuffer::GetX(x,(PIC::ParticleBuffer::byte*)ParticleData);
    node=PIC::Mesh::Search::FindBlock(x);

    PIC::CPLR::InitInterpolationStencil(x,node);
    PIC::CPLR::GetBackgroundMagneticField(B);
    AbsB=pow(B[0]*B[0]+B[1]*B[1]+B[2]*B[2],0.5) + 1E-15;

    #if _PIC_PARTICLE_MOVER__RELATIVITY_MODE_ == _PIC_MODE_ON_
    exit(__LINE__,__FILE__,"ERROR:not implemented");
    #else
    KinEnergy+= AbsB*mu;
    #endif //_PIC_PARTICLE_MOVER__RELATIVITY_MODE_ == _PIC_MODE_ON_

    *((double*)(SamplingBuffer+DatumTotalKineticEnergy.offset))+=
          //TotalKineticEnergyOffset))+=
      LocalParticleWeight*KinEnergy;
  }
}


void PIC::Mover::GuidingCenter::Init_BeforeParser(){
  // add TotalKineticEnergy to the list of sampled data
  PIC::IndividualModelSampling::DataSampledList.push_back(&Sampling::DatumTotalKineticEnergy);
}


void PIC::Mover::GuidingCenter::Init(){

}


void PIC::Mover::GuidingCenter::InitiateMagneticMoment(int spec,double *x, double *v,long int ptr, void *node) {
  PIC::Mover::GuidingCenter::InitiateMagneticMoment(spec,x,v,PIC::ParticleBuffer::GetParticleDataPointer(ptr),node);
}

void PIC::Mover::GuidingCenter::InitiateMagneticMoment(int spec,double *x, double *v,PIC::ParticleBuffer::byte *ParticleData, void *node) {
  //magnetic moment:
  // mu       = p_{perp}^2 / (2*m0*B)
  // p_{perp} = gamma*m0*v_{perp}
  //---------------------------------------------------------------
  
  // get the magnetic field
  double B[3]={0.0,0.0,0.0}, AbsB=0.0;


  //the function can be executed only the the offset for the particle magnetic moment is defined
  if (_PIC_PARTICLE_DATA__MAGNETIC_MOMENT_OFFSET_!=-1) {
    // get the magnetic field
    switch (_PIC_COUPLER_MODE_) {
    case _PIC_COUPLER_MODE__OFF_ :
      exit(__LINE__,__FILE__,"not implemented");

    default:
      PIC::CPLR::InitInterpolationStencil(x,(cTreeNodeAMR<PIC::Mesh::cDataBlockAMR>*)node);
      PIC::CPLR::GetBackgroundMagneticField(B);
      AbsB=Vector3D::Length(B)+1E-15;
    }
  
    // compute magnetic moment
    double v_par, v2, gamma2, m0, mu=0.0;
    double b[3] = {B[0]/AbsB, B[1]/AbsB, B[2]/AbsB};

    if (AbsB > 0.0) {
      v_par  = v[0]*b[0]+v[1]*b[1]+v[2]*b[2];
      v2     = v[0]*v[0]+v[1]*v[1]+v[2]*v[2];
  #if _PIC_PARTICLE_MOVER__RELATIVITY_MODE_ == _PIC_MODE_ON_
      gamma2 = 1.0 / (1.0 - v2/SpeedOfLight/SpeedOfLight);
  #else
      gamma2 = 1.0;
  #endif //_PIC_PARTICLE_MOVER__RELATIVITY_MODE_
      m0     = PIC::MolecularData::GetMass(spec);
      mu     = 0.5 * gamma2 * m0 * (v2-v_par*v_par) / AbsB;
    }

    // change the veolcity so it is aligned with magnetic field
    // and set the magnetic moment's value
    v[0] = v_par * b[0]; v[1] = v_par * b[1]; v[2] = v_par * b[2];
    PIC::ParticleBuffer::SetMagneticMoment(mu, ParticleData);
  }
}

void PIC::Mover::GuidingCenter::GuidingCenterMotion_default(
                                double *Vguide_perp,    double &ForceParal, 
				double &BAbsoluteValue, double *BDirection, 
				double *PParal,
				int spec,long int ptr,double *x,double *v,
				cTreeNodeAMR<PIC::Mesh::cDataBlockAMR>  *startNode) {
  /* function returns guiding center velocity in the direction perpendicular
   * to the magnetic field and the force parallel to it
   * for Lorentz force (considered here)
   *
   * v_{guide_perp} = 
   *  E\times B / B^2 + 
   *  \mu/(q\gamma) B\times\nabla B / B^2 +
   *  (p_{\parallel}^2)/(q\gamma m_0) B\times(B\cdot\nabla)B/B^4
   *
   * dp_{\parallel}/dt=
   *  q E_{\parallel} - \mu/\gamma \nabla_{\parallel}B
   *
   * \mu = p_{\perp}^2/(2m_0B)
   *
   * \gamma = 1/\sqrt{1-v^2/c^2}
   **********************************************************************/
  double Vguide_perp_LOC[3]={0.0,0.0,0.0},ForceParal_LOC =0.0;
  double BAbsoluteValue_LOC = 0.0, BDirection_LOC[3]={0.0,0.0,0.0};
  
//#if _FORCE_LORENTZ_MODE_ == _PIC_MODE_ON_
  // find electro-magnetic field
    double E[3]={0.0,0.0,0.0},gradB[9]={0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0}, gradAbsB[3]={0.0,0.0,0.0}, AbsB=0.0;
    double b[3]={0.0,0.0,0.0};
#if _PIC_COUPLER_MODE_ == _PIC_COUPLER_MODE__OFF_ 
  exit(__LINE__,__FILE__,"not implemented");
#else 
    double B[3]={0.0,0.0,0.0};
    
    
  // if coupler is used -> get values from it
  PIC::CPLR::InitInterpolationStencil(x,startNode);
  
  PIC::CPLR::GetBackgroundElectricField(E);
  PIC::CPLR::GetBackgroundMagneticField(B);
  AbsB=pow(B[0]*B[0]+B[1]*B[1]+B[2]*B[2],0.5) + 1E-15;
  b[0] = B[0]/AbsB; b[1] = B[1]/AbsB; b[2] = B[2]/AbsB;
  PIC::CPLR::GetBackgroundMagneticFieldGradient(gradB);
  // structure of gradB is the following
  //   gradB[0:2] = {d/dx, d/dy, d/dz} B_x
  //   gradB[3:5] = {d/dx, d/dy, d/dz} B_y
  //   gradB[6:8] = {d/dx, d/dy, d/dz} B_z
  gradAbsB[0]= b[0] * gradB[0] + b[1] * gradB[3] + b[2] * gradB[6];
  gradAbsB[1]= b[0] * gradB[1] + b[1] * gradB[4] + b[2] * gradB[7];
  gradAbsB[2]= b[0] * gradB[2] + b[1] * gradB[5] + b[2] * gradB[8];
  //  PIC::CPLR::GetBackgroundMagneticFieldMagnitudeGradient(gradAbsB);
  //  PIC::CPLR::GetBackgroundMagneticFieldMagnitude(AbsB);
#endif//_PIC_COUPLER_MODE_
  
  //......................................................................
  // calculate guiding center motion
  // misc paramteres
  double q      = PIC::MolecularData::GetElectricCharge(spec);
  double m0     = PIC::MolecularData::GetMass(  spec);
//  double c2     = SpeedOfLight*SpeedOfLight;
  double mu     = PIC::ParticleBuffer::GetMagneticMoment(ptr);

  // square of velocity of gyrations
#if _PIC_PARTICLE_MOVER__RELATIVITY_MODE_ == _PIC_MODE_ON_
  exit(__LINE__,__FILE__,"Error: not implemented");
#else
  double v_perp2= mu * 2.0 * AbsB / m0;
#endif //_PIC_PARTICLE_MOVER__RELATIVITY_MODE_

  // V^2 = Vguide_paral^2 + (Vguide_perp+Vgyr)^2
  //     = Vguide_paral^2 + Vguide_perp^2 + Vgyr^2 + 2 Vguide_perp * Vgyr
  // <Vguide_perp * Vgyr> = 0
#if _PIC_PARTICLE_MOVER__RELATIVITY_MODE_ == _PIC_MODE_ON_
  double v2     = v[0]*v[0]+v[1]*v[1]+v[2]*v[2] + v_perp2;
  double gamma  = pow(1-v2/c2,-0.5);
#else
  double gamma  = 1.0;
#endif //_PIC_PARTICLE_MOVER__RELATIVITY_MODE_
  double p_par;
  p_par = (PParal==NULL)?gamma * m0 * (v[0]*b[0]+v[1]*b[1]+v[2]*b[2]):*PParal;

  double msc,vec[3]={0.0,0.0,0.0};
  // guiding center velocity
  // 1st term
  Vguide_perp_LOC[0] += (E[1]*b[2]-E[2]*b[1])/AbsB;
  Vguide_perp_LOC[1] += (E[2]*b[0]-E[0]*b[2])/AbsB;
  Vguide_perp_LOC[2] += (E[0]*b[1]-E[1]*b[0])/AbsB ;
  // 2nd term
  msc = mu/(q*gamma)/AbsB;
  Vguide_perp_LOC[0] += msc * (b[1]*gradAbsB[2]-b[2]*gradAbsB[1]);
  Vguide_perp_LOC[1] += msc * (b[2]*gradAbsB[0]-b[0]*gradAbsB[2]);
  Vguide_perp_LOC[2] += msc * (b[0]*gradAbsB[1]-b[1]*gradAbsB[0]);
  // 3rd term
  msc    = p_par*p_par/(q*gamma*m0)/AbsB/AbsB;
  vec[0] = b[0]*gradB[0]+b[1]*gradB[1]+b[2]*gradB[2];
  vec[1] = b[0]*gradB[3]+b[1]*gradB[4]+b[2]*gradB[5];
  vec[2] = b[0]*gradB[6]+b[1]*gradB[7]+b[2]*gradB[8];
  Vguide_perp_LOC[0] += msc * (b[1]*vec[2]-b[2]*vec[1]);
  Vguide_perp_LOC[1] += msc * (b[2]*vec[0]-b[0]*vec[2]);
  Vguide_perp_LOC[2] += msc * (b[0]*vec[1]-b[1]*vec[0]);

  //parallel force
#if _PIC__IDEAL_MHD_MODE_ == _PIC_MODE_ON_
  // in this case E = - V \cross B => E_{\paral} = E*b = 0
  ForceParal_LOC = -mu/gamma * (gradAbsB[0]*b[0]+gradAbsB[1]*b[1]+gradAbsB[2]*b[2]);
#else
  ForceParal_LOC = 
    q * (E[0]*b[0]+E[1]*b[1]+E[2]*b[2]) - 
    mu/gamma * (gradAbsB[0]*b[0]+gradAbsB[1]*b[1]+gradAbsB[2]*b[2]);
#endif//_PIC__IDEAL_MHD_MODE_ == _PIC_MODE_ON_


  BAbsoluteValue_LOC = AbsB;
  memcpy(BDirection_LOC, b, 3*sizeof(double));
  //  Vguide_perp_LOC[0] = 0;  Vguide_perp_LOC[1] = 0;  Vguide_perp_LOC[2] = 0;
  //  ForceParal_LOC =0;

//#endif//_FORCE_LORENTZ_MODE_
      memcpy(Vguide_perp,    Vguide_perp_LOC,    3*sizeof(double));
      memcpy(BDirection,BDirection_LOC,3*sizeof(double));
      ForceParal     = ForceParal_LOC;
      BAbsoluteValue = BAbsoluteValue_LOC;
}


int PIC::Mover::GuidingCenter::Mover_SecondOrder(long int ptr, double dtTotal,cTreeNodeAMR<PIC::Mesh::cDataBlockAMR>* startNode){
  cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *newNode=NULL;
  double dtTemp;
  PIC::ParticleBuffer::byte *ParticleData;
  double AbsBInit=0.0, bInit[3]={0.0,0.0,0.0};
  double vInit[  3]={0.0,0.0,0.0}, pInit  =0.0, xInit[  3]={0.0,0.0,0.0};
  double AbsBMiddle=0.0, bMiddle[3]={0.0,0.0,0.0};
  double vMiddle[3]={0.0,0.0,0.0}, pMiddle=0.0, xMiddle[3]={0.0,0.0,0.0};
  double vFinal[ 3]={0.0,0.0,0.0}, pFinal =0.0, xFinal[ 3]={0.0,0.0,0.0};
//  double c2 = SpeedOfLight*SpeedOfLight;
  double xminBlock[3],xmaxBlock[3];
//  int idim;

//  long int LocalCellNumber;
  int i,j,k,spec;

//  PIC::Mesh::cDataCenterNode *cell;
//  bool MovingTimeFinished=false;

//  double xmin,xmax;

  double misc;

  ParticleData=PIC::ParticleBuffer::GetParticleDataPointer(ptr);
  PIC::ParticleBuffer::GetV(vInit,ParticleData);
  PIC::ParticleBuffer::GetX(xInit,ParticleData);
  spec=PIC::ParticleBuffer::GetI(ParticleData);
  double m0 = PIC::MolecularData::GetMass(spec);
  double mu = PIC::ParticleBuffer::GetMagneticMoment(ptr);

  static long int nCall=0;

  nCall++;

  memcpy(xminBlock,startNode->xmin,DIM*sizeof(double));
  memcpy(xmaxBlock,startNode->xmax,DIM*sizeof(double));
  
//  MovingTimeFinished=true;

  double Vguide_perpInit[3]={0.0,0.0,0.0}, ForceParalInit=0.0;

  // Integrate the equations of motion
  // use predictor-corrector scheme
  /***** Guiding center motion: ******
   * dx/dt     = Vguide_perp + Vparal*                   
   * dPparal/dt= ForceParal          *
   * Pparal    = gamma * m0 * Vparal *
   ***********************************/

  // predictor step
  
#if _PIC_PARTICLE_MOVER__FORCE_INTEGRTAION_MODE_ == _PIC_PARTICLE_MOVER__FORCE_INTEGRTAION_MODE__ON_
  
  _PIC_PARTICLE_MOVER__GUIDING_CENTER_MOTION_(Vguide_perpInit,ForceParalInit,AbsBInit,bInit,NULL,spec,ptr,xInit,vInit,startNode);

#endif

  misc = pow(vInit[0]*vInit[0]+vInit[1]*vInit[1]+vInit[2]*vInit[2],0.5);
  if(vInit[0]*bInit[0]+vInit[1]*bInit[1]+vInit[2]*bInit[2] < 0) misc *= -1.0;

  vInit[0] = misc * bInit[0];
  vInit[1] = misc * bInit[1];
  vInit[2] = misc * bInit[2];

#if _PIC_PARTICLE_MOVER__RELATIVITY_MODE_ == _PIC_MODE_ON_
  pInit=
    pow(1-(misc*misc+2*mu*AbsBInit/m0)/c2,-0.5)*
    m0*(vInit[0]*bInit[0]+vInit[1]*bInit[1]+vInit[2]*bInit[2]);
#else
  pInit=m0*(vInit[0]*bInit[0]+vInit[1]*bInit[1]+vInit[2]*bInit[2]);
#endif //_PIC_PARTICLE_MOVER__RELATIVITY_MODE_

  

  dtTemp=dtTotal/2.0;
  // advance coordinates half-step
  xMiddle[0]=xInit[0] + dtTemp * (Vguide_perpInit[0] + vInit[0]);
  xMiddle[1]=xInit[1] + dtTemp * (Vguide_perpInit[1] + vInit[1]);
  xMiddle[2]=xInit[2] + dtTemp * (Vguide_perpInit[2] + vInit[2]);
  // advance momentum half-step
  pMiddle   =pInit + dtTemp * ForceParalInit; 

#if _PIC_SYMMETRY_MODE_ == _PIC_SYMMETRY_MODE__AXIAL_
  //rotate the middle position
  
  // rotate to the y=0 plane
  double cosPhiMiddle, sinPhiMiddle, vTmpXMiddle, vTmpYMiddle;
  double xNormMiddle = pow(xMiddle[0]*xMiddle[0]+xMiddle[1]*xMiddle[1], 0.5);
  cosPhiMiddle = xMiddle[0] / xNormMiddle;
  sinPhiMiddle = xMiddle[1] / xNormMiddle;
  xMiddle[0] = xNormMiddle;
  xMiddle[1] = 0.0;
  //  vTmpXMiddle = vMiddle[0]; vTmpYMiddle = vMiddle[1];
  //  vMiddle[0] = vTmpXMiddle*cosPhiMiddle + vTmpYMiddle*sinPhiMiddle;
  //  vMiddle[1] =-vTmpXMiddle*sinPhiMiddle + vTmpYMiddle*cosPhiMiddle;
#endif //_PIC_SYMMETRY_MODE_ == _PIC_SYMMETRY_MODE__AXIAL_ 


  // check if a particle has left the domain
  newNode=PIC::Mesh::Search::FindBlock(xMiddle);
  if (newNode==NULL) { 
    //the particle left the computational domain
    int code=_PARTICLE_DELETED_ON_THE_FACE_;
    
    //call the function to processes particles that left the domain
    switch(code){
    case _PARTICLE_DELETED_ON_THE_FACE_:
      PIC::ParticleBuffer::DeleteParticle(ptr);
      return _PARTICLE_LEFT_THE_DOMAIN_;
    default:
      exit(__LINE__,__FILE__,"Error: not implemented");
    }
    
  }


  // corrector step
  double Vguide_perpMiddle[3]={0.0,0.0,0.0}, ForceParalMiddle=0.0;
  
#if _PIC_PARTICLE_MOVER__FORCE_INTEGRTAION_MODE_ == _PIC_PARTICLE_MOVER__FORCE_INTEGRTAION_MODE__ON_
  
  _PIC_PARTICLE_MOVER__GUIDING_CENTER_MOTION_(Vguide_perpMiddle,ForceParalMiddle,AbsBMiddle,bMiddle,&pMiddle,spec,ptr,xMiddle,vMiddle,newNode);

#endif

#if _PIC_SYMMETRY_MODE_ == _PIC_SYMMETRY_MODE__AXIAL_
  //rotate the middle position
  
  // rotate back to the original position
  xMiddle[0]  = xNormMiddle*cosPhiMiddle;
  xMiddle[1]  = xNormMiddle*sinPhiMiddle;
  //  vTmpXMiddle = vMiddle[0]; vTmpYMiddle = vMiddle[1];
  //  vMiddle[0]  = vTmpXMiddle*cosPhiMiddle - vTmpYMiddle*sinPhiMiddle;
  //  vMiddle[1]  = vTmpXMiddle*sinPhiMiddle + vTmpYMiddle*cosPhiMiddle;
  double bTmpXMiddle, bTmpYMiddle;
  bTmpXMiddle = bMiddle[0]; bTmpYMiddle = bMiddle[1];
  bMiddle[0]  = bTmpXMiddle*cosPhiMiddle - bTmpYMiddle*sinPhiMiddle;
  bMiddle[1]  = bTmpXMiddle*sinPhiMiddle + bTmpYMiddle*cosPhiMiddle;
  vTmpXMiddle = Vguide_perpMiddle[0]; vTmpYMiddle = Vguide_perpMiddle[1];
  Vguide_perpMiddle[0] = vTmpXMiddle*cosPhiMiddle - vTmpYMiddle*sinPhiMiddle;
  Vguide_perpMiddle[1] = vTmpXMiddle*sinPhiMiddle + vTmpYMiddle*cosPhiMiddle;
#endif //_PIC_SYMMETRY_MODE_ == _PIC_SYMMETRY_MODE__AXIAL_ 


#if _PIC_PARTICLE_MOVER__RELATIVITY_MODE_ == _PIC_MODE_ON_
  // estimate parallel velocity
  exit(__LINE__,__FILE__,"not implemetned");
#else
  misc       = pMiddle / m0;
  vMiddle[0] = misc * bMiddle[0];
  vMiddle[1] = misc * bMiddle[1];
  vMiddle[2] = misc * bMiddle[2];
#endif //_PIC_PARTICLE_MOVER__RELATIVITY_MODE_



  // advance coordinates full-step
  xFinal[0]=xInit[0] + dtTotal * (Vguide_perpMiddle[0] + vMiddle[0]);
  xFinal[1]=xInit[1] + dtTotal * (Vguide_perpMiddle[1] + vMiddle[1]);
  xFinal[2]=xInit[2] + dtTotal * (Vguide_perpMiddle[2] + vMiddle[2]);
  // advance momentum full-step
  pFinal   =pInit + dtTotal * ForceParalMiddle; 

#if _PIC_PARTICLE_MOVER__RELATIVITY_MODE_ == _PIC_MODE_ON_
  // estimate parallel velocity
  exit(__LINE__,__FILE__,"not implemetned");
#else
  misc       = pFinal / m0;
  vFinal[0] = misc * bMiddle[0];
  vFinal[1] = misc * bMiddle[1];
  vFinal[2] = misc * bMiddle[2];
#endif //_PIC_PARTICLE_MOVER__RELATIVITY_MODE_


#if _PIC_SYMMETRY_MODE_ == _PIC_SYMMETRY_MODE__AXIAL_
  //rotate the final position
  
  // rotate to the y=0 plane
  double cosPhiFinal, sinPhiFinal, vTmpXFinal, vTmpYFinal;
  double xNormFinal = pow(xFinal[0]*xFinal[0]+xFinal[1]*xFinal[1], 0.5);
  cosPhiFinal = xFinal[0] / xNormFinal;
  sinPhiFinal = xFinal[1] / xNormFinal;
  xFinal[0] = xNormFinal;
  xFinal[1] = 0.0;
  vTmpXFinal = vFinal[0]; vTmpYFinal = vFinal[1];
  vFinal[0] = vTmpXFinal*cosPhiFinal + vTmpYFinal*sinPhiFinal;
  vFinal[1] =-vTmpXFinal*sinPhiFinal + vTmpYFinal*cosPhiFinal;
  
#endif //_PIC_SYMMETRY_MODE_ == _PIC_SYMMETRY_MODE__AXIAL_ 



  //interaction with the faces of the block and internal surfaces
  //check whether the particle trajectory is intersected the spherical body
#if _TARGET_ID_(_TARGET_) != _TARGET_NONE__ID_
  double rFinal2;

  //if the particle is inside the sphere -> apply the boundary condition procedure
  if ((rFinal2=xFinal[0]*xFinal[0]+xFinal[1]*xFinal[1]+xFinal[2]*xFinal[2])<_RADIUS_(_TARGET_)*_RADIUS_(_TARGET_)) {
    double r=sqrt(rFinal2);
    int code;

    static cInternalSphericalData_UserDefined::fParticleSphereInteraction ParticleSphereInteraction=
        ((cInternalSphericalData*)(PIC::Mesh::mesh.InternalBoundaryList.front().BoundaryElement))->ParticleSphereInteraction;
    static void* BoundaryElement=PIC::Mesh::mesh.InternalBoundaryList.front().BoundaryElement;

    //move the particle location at the surface of the sphere
    for (int idim=0;idim<DIM;idim++) xFinal[idim]*=_RADIUS_(_TARGET_)/r;

    //determine the block of the particle location
    newNode=PIC::Mesh::mesh.findTreeNode(xFinal,startNode);

    //apply the boundary condition
    code=ParticleSphereInteraction(spec,ptr,xFinal,vFinal,dtTotal,(void*)newNode,BoundaryElement);

    if (code==_PARTICLE_DELETED_ON_THE_FACE_) {
      PIC::ParticleBuffer::DeleteParticle(ptr);
      return _PARTICLE_LEFT_THE_DOMAIN_;
    }
  }
  else {
    newNode=PIC::Mesh::mesh.findTreeNode(xFinal,startNode);
  }
#else
  newNode=PIC::Mesh::mesh.findTreeNode(xFinal,startNode);
#endif //_TARGET_ == _TARGET_NONE_
    
  //advance the particle's position and velocity
  //interaction with the faces of the block and internal surfaces
  
  if (newNode==NULL) {
    
    //the particle left the computational domain
    int code=_PARTICLE_DELETED_ON_THE_FACE_;
    
    //call the function that process particles that leaved the coputational domain
    switch(code){
    case _PARTICLE_DELETED_ON_THE_FACE_:
      PIC::ParticleBuffer::DeleteParticle(ptr);
      return _PARTICLE_LEFT_THE_DOMAIN_;
    default:
      exit(__LINE__,__FILE__,"Error: not implemented");
    }
    
  }



  //adjust the value of 'startNode'
  startNode=newNode;
  memcpy(vInit,vFinal,3*sizeof(double));
  memcpy(xInit,xFinal,3*sizeof(double));
  
  //save the trajectory point
#if _PIC_PARTICLE_TRACKER_MODE_ == _PIC_MODE_ON_
  PIC::ParticleTracker::RecordTrajectoryPoint(xInit,vInit,spec,ParticleData,(void*)startNode);
#endif
  
  
  
  
#if _PIC_PARTICLE_TRACKER_MODE_ == _PIC_MODE_ON_
#if _PIC_PARTICLE_TRACKER__TRACKING_CONDITION_MODE__DYNAMICS_ == _PIC_MODE_ON_
  PIC::ParticleTracker::ApplyTrajectoryTrackingCondition(xFinal,vFinal,spec,ParticleData,(void*)startNode);
#endif
#endif
  
  

  //finish the trajectory integration procedure
  PIC::Mesh::cDataBlockAMR *block;
  long int tempFirstCellParticle,*tempFirstCellParticlePtr;

  if (PIC::Mesh::mesh.fingCellIndex(xFinal,i,j,k,newNode,false)==-1) exit(__LINE__,__FILE__,"Error: cannot find the cellwhere the particle is located");

  if ((block=newNode->block)==NULL) {
    exit(__LINE__,__FILE__,"Error: the block is empty. Most probably hte tiime step is too long");
  }
  
#if _COMPILATION_MODE_ == _COMPILATION_MODE__MPI_
  tempFirstCellParticlePtr=block->tempParticleMovingListTable+i+_BLOCK_CELLS_X_*(j+_BLOCK_CELLS_Y_*k);
#elif _COMPILATION_MODE_ == _COMPILATION_MODE__HYBRID_
  tempFirstCellParticlePtr=block->GetTempParticleMovingListTableThread(omp_get_thread_num(),i,j,k);
#else
#error The option is unknown
#endif

  tempFirstCellParticle=(*tempFirstCellParticlePtr);

  PIC::ParticleBuffer::SetV(vFinal,ParticleData);
  PIC::ParticleBuffer::SetX(xFinal,ParticleData);

  PIC::ParticleBuffer::SetNext(tempFirstCellParticle,ParticleData);
  PIC::ParticleBuffer::SetPrev(-1,ParticleData);

  if (tempFirstCellParticle!=-1) PIC::ParticleBuffer::SetPrev(ptr,tempFirstCellParticle);
  *tempFirstCellParticlePtr=ptr;


  return _PARTICLE_MOTION_FINISHED_;
}