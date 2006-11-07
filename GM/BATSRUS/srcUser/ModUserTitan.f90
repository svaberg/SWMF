!^CFG COPYRIGHT UM
!========================================================================
Module ModUser
  ! This is the default user module which contains empty methods defined
  ! in ModUserEmpty.f90
  !
  ! Please see the documentation, and the files ModUserEmpty.f90 and 
  ! srcUser/ModUserExamples.f90 for information about what the different user
  ! subroutines do and how to implement them for your specific problem.

  use ModSize
  use ModVarIndexes, ONLY: rho_, Ux_, Uy_, Uz_,p_,Bx_, By_, Bz_,&
       rhoLp_,rhoMp_,MassSpecies_V,SpeciesFirst_,SpeciesLast_  
  use ModUserEmpty,               &
       IMPLEMENTED1 => user_read_inputs,                &
       IMPLEMENTED2 => user_init_session,               &
       IMPLEMENTED3 => user_set_ics,                    &
       IMPLEMENTED4 => user_set_boundary_cells,         &
       IMPLEMENTED5 => user_face_bcs,                   &
       IMPLEMENTED6 => user_calc_sources,               &
       IMPLEMENTED7 => user_update_states,              &
       IMPLEMENTED8 => user_set_plot_var      

  include 'user_module.h' !list of public methods

  !\
  ! Here you must define a user routine Version number and a 
  ! descriptive string.
  !/
  real,              parameter :: VersionUserModule = 1.0
  character (len=*), parameter :: NameUserModule = &
       'Titan 7 species MHD code, Yingjuan Ma'

  ! Venus stuff
  logical,public ::  UseMultiSpecies=.true.
  integer, parameter :: MaxNuSpecies=10, MaxReactions=30

  integer, parameter, public :: MaxSpecies=7

  integer,public :: nSpecies=7, nNuSpecies=10, &
       nReactions=25
  real,  dimension(1:nI, 1:nJ, 1:nK, nBLK,MaxNuSpecies) :: &
       nDenNuSpecies_CBI    !number density of neutral Species

  real,  dimension(1:nI, 1:nJ, 1:nK, nBLK,MaxSpecies) :: &
       PhoIon_I, Recb_I    !photonionzation and recombination rate 

  real, dimension(MaxReactions) :: ReactionRate_I
  real, dimension(MaxReactions,MaxSpecies):: CoeffSpecies_II, &
       dSdRho_II !, dLdRho_II
  real, dimension(MaxSpecies)::LossSpecies_I, &
       SiSpecies_I,  LiSpecies_I
  !        dStndRho_I,  dLtdRho_I,  dLtndNumRho_I, &
  real:: totalNumRho, totalLossRho, totalLossNumRho, &
       totalSourceNumRho, totalLossx, totalLossNumx, totalSourceRho

  real,  dimension(1:nI, 1:nJ, 1:nK, nBLK) :: &
       MaxSiSpecies_CB,  MaxLiSpecies_CB
  common /TimeBlock/ MaxSiSpecies_CB,  MaxLiSpecies_CB

  real,  dimension(1:nI, 1:nJ, 1:nK, nBLK) :: &
       MaxSLSpecies_CB

  !the reactions considered:(p means ion, em means electron)
  !the prefered order of a reaction is ions, Nus, hv and electrons
  integer, parameter :: &!reaction number
       M_hv__Mp_em_    = 1, &
       H1_hv__H1p_em_  = 2, &
       L_hv__Lp_em_    = 3, &
       Lp_em__L_       = 4, &
       Mp_em__M_       = 5, &
       H1p_em__H1_     = 6, &
       H2p_em__H2_     = 7, &
       MHCp_em__MHC_   = 8, &
       HHCp_em__HHC_   = 9, &
       HNIp_em__HNI_   = 10,&
       Lp_CH4__H1p_X_  = 11, &
       Lp_N2__Mp_X_    = 12, &
       Mp_CH4__H2p_X_  = 13, &
       Mp_C2H4__H1p_X_ = 14, &
       Mp_C2H6__H1p_X_ = 15, &
       H1p_HCN__H2p_X_ = 16, &
       H1p_HC3N__HNIp_X_ = 17, &
       H1p_C2H2__MHCp_X_ = 18, &
       H1p_C2H4__MHCp_X_ = 19, &
       H2p_HC3N__HNIp_X_ = 20, &
       H2p_C4H2__MHCp_X_ = 21, &
       MHCp_C2H2__HHCp_X_= 22, &
       MHCp_C2H4__HHCp_X_= 23, &
       MHCp_C3H4__HHCp_X_= 24, &
       MHCp_C4H2__HHCp_X_= 25

  integer, parameter :: &! order of ion species
       Lp_   = 1, &
       Mp_   = 2, &
       H1p_  = 3, &
       H2p_  = 4, &
       MHCp_ = 5, &
       HHCp_ = 6, &
       HNIp_ = 7
  integer, parameter :: & ! order of Neutral species
       N2_  = 1, &
       CH4_ = 2, &
       L_   = 3, &
       C3H4_= 4, & !
       C4H2_= 5, & !
       C2H2_= 6, &
       C2H4_= 7, &
       HCN_ = 8, &
       C2H6_= 9, &
       HC3N_=10

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  real, dimension(MaxReactions) :: Rate_I
  real, dimension(MaxReactions) :: Ratedim_I

  character (len=10), dimension(MaxSpecies):: &
       ion_name_I

!  real,public ::  &
!       MassSpecies_V(MaxSpecies)=1.0  !atm

  real, dimension(MaxNuSpecies)::  NuMassSpecies_I, &
       HNuSpecies_I, BodynDenNuSpdim_I,&
       BodynDenNuSpecies_I   

  real, dimension(MaxSpecies):: BodyRhoSpecies_I
  integer, parameter :: & ! other numbers
       em_=-1 ,&
       hv_=-2   

  real:: XiT0 !dimensionless temperature of new created ions
  real :: body_Ti_dim  !ion temperature at the body
  real,  dimension(1:nI,1:nJ,1:nK,nBLK) :: nu_BLK
  real :: nu0_dim,nu0

  logical :: UseTitanInput = .True.
  logical :: UseImpact =.false.
  character*30 :: SolarCnd
  integer, parameter :: num_Te = 9500, num_Ri = 199, num_nu=229
  !, num_n = 9500
  !  real, dimension(1:num_n) :: tmp_rn, tmp_hn, tmp_nL, tmp_nM, tmp_nH
  real, dimension(10,1:num_nu):: tmp_n
  real, dimension(1:num_nu):: tmp_hn
  real, dimension(1:num_Te) :: tmp_hT, tmp_Te
  real, dimension(1:num_Ri) :: tmp_hR 

  !  real, dimension(1:9):: SZATitan, cos_ISZA
  !  real, dimension(1:9,1:num_Ri):: tmp_RL0, tmp_RM0,tmp_RH0

  integer :: maxSZAm =12
  real, dimension(1:12):: SZATitan, cos_ISZA
  real, dimension(1:12,1:num_Ri):: tmp_RL0, tmp_RM0,tmp_RH0
  real, dimension(1:num_Ri):: IMPACT_L, IMPACT_M,IMPACT_H

  real, dimension(1:7,1:num_Ri):: tmp_ion
  real:: SW_Lp, SW_Mp,  SW_Lp_dim, SW_Mp_dim,Plas_T_ev
  real:: Plas_rho,AVER_mass, Plas_T  

  !\
  ! The following are needed in user_sources::
  !/
  real, dimension(1:nI,1:nJ,1:nK):: &
       Srho,SrhoUx,SrhoUy,SrhoUz,SBx,SBy,SBz,Sp,SE
  real, dimension(MaxSpecies,1:nI,1:nJ,1:nK) :: &
       SrhoSpecies


!  real:: SX0=0.673, SY0=0.663, SZ0=-0.32 !for T9 flyby
  real:: SX0=1.0, SY0=0.0, SZ0=0.0   !for symetric case
  !  real:: SX0=-0.325568, SY0=-0.945519, SZ0=0.0  !71  degree from -x
  !  real:: SX0=0.174, SY0=-0.9848, SZ0=0.0        !100 degree from -x
  !  real:: SX0=0.342, SY0=-0.9397, SZ0=0.0        !110 degree from -x
  !  real:: SX0=0.303654, SY0=-0.85936,SZ0=-0.3907 !long=110, lat=-23
  !  !from -x for Ta & Tb
  !  real:: SX0=0.9116, SY0=0.1697,SZ0=-0.374      !long=10.55, lat=-22
  !  !from x for T5


contains
  !=============================================================================

  subroutine user_read_inputs
    use ModProcMH,    ONLY: iProc
    use ModReadParam
    use ModPhysics, ONLY:SW_RHO_DIM, SW_T_DIM

    character (len=100) :: NameCommand
    !    character (len=100) :: line
    character (len=100) :: linetitan
    integer:: i, j
    !---------------------------------------------------------------------------

    do
       if(.not.read_line() ) EXIT
       if(.not.read_command(NameCommand)) CYCLE
       select case(NameCommand)

       case('#SUBSOLARLOC')
          call read_var('SX0',SX0)
          call read_var('SY0',SY0)
          call read_var('SZ0',SZ0)

       case('#UPSTREAM')
          call read_var('SW_LP_dim', SW_LP_dim)
          call read_var('SW_LP_dim', SW_MP_dim)        
          call read_var('plas_T_ev', plas_T_ev)        
          SW_LP=SW_LP_dim*MassSpecies_V(rhoLp_)
          SW_MP=SW_MP_dim*MassSpecies_V(rhoMp_)
          Plas_rho =  SW_LP + SW_MP 
          SW_LP= SW_LP/Plas_rho 
          SW_MP= SW_MP/Plas_rho 
          AVER_mass = Plas_rho/(SW_LP_dim+SW_MP_dim)
          plas_T = plas_T_ev/AVER_mass*1.1610e4          
          if(iproc==0)then
             write(*,*)'AVER_mass=',AVER_mass           
             write(*,*)'plas_T=',plas_T
          end if
          !          if(UseMultiSpecies)then
         SW_rho_dim = Plas_rho
          SW_T_dim = plas_T      
          !          end if
          write(*,*)'SW_rho_dim=',SW_rho_dim,SW_T_dim
          case('#USETITANINPUT')
          call read_var('UseTitanInput',UseTitanInput)
          call read_var('SolarCnd',SolarCnd)
          call read_var('UseImpact',UseImpact)

          if(UseTitanInput)then
             open(15,file="TitanInput/T_e.dat",status="old")
             read(15,*) (tmp_hT(i),tmp_Te(i),i=1,num_Te)
             close(15)

             select case(SolarCnd)
             case("Solarmax")              
                maxSZAm = 9
                open(15, file ="TitanInput/SZALIST_9.dat",status="old")              
                read(15,'(a)')linetitan
                read(15,*) (SZATitan(j),j=1,maxSZAm)  
                close(15)

                open(15,file="TitanInput/HighsolarH.dat",status="old")
                read(15,'(a)')linetitan
                !           write(*,*)'line1titan=', linetitan
                do i=1,num_Ri
                   read(15,*) tmp_hR(i),(tmp_RH0(j,i),j=1,maxSZAm)              
                   !write(*,'(10g10.4)')tmp_hR(i),tmp_RH0(1:12,i)             
                end do
                close(15)
                open(15,file="TitanInput/HighsolarM.dat",status="old")
                read(15,'(a)')linetitan
                !          write(*,*)'line2titan=', linetitan
                do i=1,num_Ri
                   read(15,*) tmp_hR(i),(tmp_RM0(j,i),j=1,maxSZAm)
                end do
                close(15)
                open(15,file="TitanInput/HighsolarL.dat",status="old")
                read(15,'(a)')linetitan
                !          write(*,*)'line3titan=', linetitan
                do i=1,num_Ri
                   read(15,*)tmp_hR(i),(tmp_RL0(j,i),j=1,maxSZAm)
                end do
                close(15)

                open(15,file="TitanInput/TitanDen60degmax.dat",status="old")
                read(15,'(a)')linetitan
                !           write(*,*)'line5titan=', linetitan
                read(15,'(a)')linetitan
                do i=1,num_Ri
                   read(15,*)tmp_hR(i),(tmp_ion(j,i),j=1,7)
                end do
                close(15)    

                open(15,file="TitanInput/NEUTRALDENSITY.dat",status="old")
                read(15,'(a)')linetitan
                do i=1,num_nu
                   read(15,*)tmp_hn(i),(tmp_n(j,i),j=1,10)
                end do
                close(15)

             case("Solarmin")

                maxSZAm = 9

                open(15, file ="TitanInput/SZALIST_9.dat",status="old")              
                read(15,'(a)')linetitan
                read(15,*) (SZATitan(j),j=1,maxSZAm)  
                close(15)
                write(*,*)SZATitan

                open(15,file="TitanInput/LowsolarH.dat",status="old")
                read(15,'(a)')linetitan
                !           write(*,*)'line1titan=', linetitan
                do i=1,num_Ri
                   read(15,*) tmp_hR(i),(tmp_RH0(j,i),j=1,maxSZAm)              
                end do
                close(15)

                open(15,file="TitanInput/LowsolarM.dat",status="old")
                read(15,'(a)')linetitan
                !          write(*,*)'line2titan=', linetitan
                do i=1,num_Ri
                   read(15,*) tmp_hR(i),(tmp_RM0(j,i),j=1,maxSZAm)
                end do
                close(15)
                open(15,file="TitanInput/LowsolarL.dat",status="old")
                read(15,'(a)')linetitan
                !          write(*,*)'line3titan=', linetitan
                do i=1,num_Ri
                   read(15,*)tmp_hR(i),(tmp_RL0(j,i),j=1,maxSZAm)
                end do
                close(15)

                open(15,file="TitanInput/TitanDen60degmin.dat",status="old")
                read(15,'(a)')linetitan
                read(15,'(a)')linetitan
                !           write(*,*)'line5titan=', linetitan
                do i=1,num_Ri
                   read(15,*)tmp_hR(i),(tmp_ion(j,i),j=1,7)
                end do
                close(15)

                open(15,file="TitanInput/NEUTRALDENSITY.dat",status="old")
                read(15,'(a)')linetitan
                do i=1,num_nu
                   read(15,*)tmp_hn(i),(tmp_n(j,i),j=1,10)
                end do
                close(15)

             case("CassiniTA")                        
                maxSZAm = 12
                open(15, file ="TitanInput/SZALIST_12.dat",status="old")              
                read(15,'(a)')linetitan
                read(15,*) (SZATitan(j),j=1,maxSZAm)  
                close(15)
                if(iproc==0)write(*,*)'CassiniTA',SZATitan

                open(15,file="TitanInput/HsolarPrdJan05.txt",status="old")
                read(15,'(a)')linetitan
                if(iproc==0)write(*,*)'HH line1titan=', linetitan
                read(15,'(a)')linetitan
                if(iproc==0)write(*,*)'HH line2titan=', linetitan
                do i=1,num_Ri
                   read(15,*) tmp_hR(i),(tmp_RH0(j,i),j=1,maxSZAm)              
                   !if(iproc==1)write(*,*)tmp_hR(i),tmp_RH0(1:9,i)             
                end do
                close(15)
                if(iproc==0)write(*,*)'end of HH',tmp_hR(num_Ri),&
                     tmp_RH0(1:maxSZAm,num_Ri)

                open(15,file="TitanInput/MsolarPrdJan05.txt",status="old")
                read(15,'(a)')linetitan
                if(iproc==0)write(*,*)'MM line1titan=', linetitan
                read(15,'(a)')linetitan
                if(iproc==0)write(*,*)'MM line2titan=', linetitan
                do i=1,num_Ri
                   read(15,*) tmp_hR(i),(tmp_RM0(j,i),j=1,maxSZAm)
                end do
                close(15)

                open(15,file="TitanInput/LsolarPrdJan05.txt",status="old")
                read(15,'(a)')linetitan
                if(iproc==0)write(*,*)'LL line1titan=', linetitan
                read(15,'(a)')linetitan
                if(iproc==0)write(*,*)'LL line2titan=', linetitan
                do i=1,num_Ri
                   read(15,*)tmp_hR(i),tmp_hR(i),(tmp_RL0(j,i),j=1,maxSZAm)
                end do
                close(15)

                open(15,file="TitanInput/TitanDen60degmin.dat",status="old")
                read(15,'(a)')linetitan
                !           write(*,*)'line5titan=', linetitan
                read(15,'(a)')linetitan
                do i=1,num_Ri
                   read(15,*)tmp_hR(i),(tmp_ion(j,i),j=1,7)
                end do
                close(15)    

                open(15,file="TitanInput/NEUTRALdENJan05.txt",status="old")
                read(15,'(a)')linetitan
                do i=1,num_nu
                   read(15,*)tmp_hn(i),(tmp_n(j,i),j=1,10)
                end do
                close(15)
             end select

             if(UseImpact)then
                open(15,file="TitanInput/magnetopara100evTatoub.txt",status="old")
                read(15,'(a)')linetitan
                do i=1,num_Ri
                   read(15,*)tmp_hR(i),IMPACT_L(i),IMPACT_M(i),IMPACT_H(i)
                   !              tmp_RL0(:,i)=tmp_RL0(:,i)+IMPACT_L(i)
                   !              tmp_RM0(:,i)=tmp_RM0(:,i)+IMPACT_M(i)
                   !              tmp_RH0(:,i)=tmp_RH0(:,i)+IMPACT_H(i)
                end do
                close(15)
             end if

             !open(15,file="Titan60szared_7.dat",status="old")
             !read(15,'(a)')linetitan
             !write(*,*)'line5titan=', linetitan
             !do i=1,num_Ri
             !  read(15,*)tmp_hR(i),(tmp_ion(j,i),j=1,7)
             !end do
             !close(15)

             if(iproc==0)then
                write(*,*)'tmp_hR(num_Ri)',tmp_hR(num_Ri)
                write(*,*)'tmp_hn(num_nu)',tmp_hn(num_nu)
                write(*,*)'tmp_hT(num_Te)',tmp_hT(num_Te)              
             end if
             !write(*,*)'tmpRH0(1,3)=',tmp_RH0(1,3),&
             !'tmpRL0(1,3)=',tmp_RL0(1,3),'Te(1)=', Tmp_Te(1)
             ! write(*,*)'tmp_hn(1:3)=',tmp_hn(1:3),&
             !'tmp_n(1,11:12)=',tmp_n(1,11:12)

          end if

       case('#USERINPUTEND')
          if(iProc==0) write(*,*)'USERINPUTEND'
          EXIT
       case default
          if(iProc==0) call stop_mpi( &
               'read_inputs: unrecognized command: '//NameCommand)
       end select
    end do
  end subroutine user_read_inputs


  !=============================================================================
  subroutine user_calc_sources
    use ModAdvance,  ONLY: Source_VC,Energy_
    use ModNumConst, ONLY: cZero
    use ModVarIndexes, ONLY: rhoUx_, rhoUy_, rhoUz_
    use ModMain, ONLY: iTest, jTest, kTest, ProcTest, BlkTest, &
         GLOBALBLK
    use ModProcMH,   ONLY: iProc

    logical :: oktest,oktest_me
    !------------------------------------------------------------------------  
    if(iProc==PROCtest .and. globalBLK==BLKtest)then
       call set_oktest('user_calc_sources',oktest,oktest_me)
    else
       oktest=.false.; oktest_me=.false.
    end if


    Srho   = cZero
    SrhoSpecies=cZero
    SrhoUx = cZero
    SrhoUy = cZero
    SrhoUz = cZero
    SBx    = cZero
    SBy    = cZero
    SBz    = cZero
    SP     = cZero
    SE     = cZero
    if(oktest_me)then
    !   write(*,*)'before Source(rhoU)=', Source_VC(6:8,itest,jtest,ktest)
       write(*,*)'Source(p,E)', Source_VC(P_:P_+1,iTest,jTest,kTest)
    end if
    
    call user_sources
    Source_VC(rho_       ,:,:,:) = Srho+Source_VC(rho_,:,:,:)
    Source_VC(rho_+1:rho_+MaxSpecies,:,:,:) = &
         SrhoSpecies+Source_VC(rho_+1:rho_+MaxSpecies,:,:,:)
    Source_VC(rhoUx_     ,:,:,:) = SrhoUx+Source_VC(rhoUx_,:,:,:)
    Source_VC(rhoUy_     ,:,:,:) = SrhoUy+Source_VC(rhoUy_,:,:,:)
    Source_VC(rhoUz_     ,:,:,:) = SrhoUz+Source_VC(rhoUz_,:,:,:)
    Source_VC(Bx_        ,:,:,:) = SBx+Source_VC(Bx_,:,:,:)
    Source_VC(By_        ,:,:,:) = SBy+Source_VC(By_,:,:,:)
    Source_VC(Bz_        ,:,:,:) = SBz+Source_VC(Bz_,:,:,:)
    Source_VC(P_     ,:,:,:) = SP+Source_VC(P_,:,:,:)
    Source_VC(Energy_,:,:,:) = SE+Source_VC(Energy_,:,:,:)

    if(oktest_me)then
       write(*,*)'After Source(rho, rhoSp)=', &
            Source_VC(rho_:8,iTest,jTest,kTest)
       write(*,*)'Source(rhoU)=', Source_VC(9:11,iTest,jTest,kTest)
       write(*,*)'Source(B)=', Source_VC(12:14,iTest,jTest,kTest)
       write(*,*)'Source(p,E)', Source_VC(P_:P_+1,iTest,jTest,kTest)
    end if
  end subroutine user_calc_sources
  !========================================================================
  !  SUBROUTINE USER_SOURCES
  !========================================================================
  !\
  ! This subroutine is used to calculate sources for the MHD equations.  The
  ! routine is called for each block separately so that the user would typically
  ! need only to code the source term calculation for a single block (in other
  ! words inside the the k,j,i loop below).  As with all user subroutines, the
  ! variables declared in ModUser are available here.  Again, as with other
  ! user subroutines DO NOT MODIFY ANY GLOBAL VARIABLE DEFINED IN THE MODULES
  ! INCLUDED IN THIS SUBROUTINE UNLESS SPECIFIED!!
  !
  ! The user should load the global variables:
  !      Srho,SrhoUx,SrhoUy,SrhoUz,SBx,SBy,SBz,SE,SP,SEw
  !
  ! Note that SE (energy) and SP (pressure) must both be loaded if the code is 
  ! going to use both the primitive and the conservative MHD equation advance  
  ! (see the USER MANUAL and the DESIGN document).  If using only primitive SP 
  ! must be loaded.  If using only conservative SE must be loaded.  The safe
  ! approach is to load both.
  !/
  subroutine user_sources
    use ModMain, ONLY: PROCTEST,GLOBALBLK,BLKTEST, iTest,jTest,kTest 
    use ModAdvance,  ONLY: State_VGB,Theat0,           &
         B0xCell_BLK,B0yCell_BLK,B0zCell_BLK,UDotFA_X,UDotFA_Y,  &
         UDotFA_Z,VdtFace_x,VdtFace_y,VdtFace_z
    use ModGeometry, ONLY: x_BLK,y_BLK,z_BLK,R_BLK,&
         vInv_CB
    use ModConst,    ONLY: cZero,cHalf,cOne,cTwo,cTolerance
    use ModProcMH,   ONLY: iProc
    use ModPhysics,  ONLY: Rbody, inv_gm1

    ! Variables required by this user subroutine
    integer:: i,j,k,iSpecies
    real :: inv_rho, inv_rho2, uu2, cosSZA, Productrate
    real :: alt, Te_dim = 300.0
    real :: totalPSNumRho=0.0,totalRLNumRhox=0.0
    logical:: oktest,oktest_me
    !
    !---------------------------------------------------------------------------
    !\
    ! Variable meanings:
    !   Srho: Source terms for the continuity equation
    !   SE,SP: Source terms for the energy (conservative) and presure
    !          (primative) equations
    !   SrhoUx,SrhoUy,SrhoUz:  Source terms for the momentum equation
    !   SBx,SBy,SBz:  Souce terms for the magnetic field equations 
    !/
    !---------------------------------------------------------------------------
    !
    if (iProc==PROCtest.and.globalBLK==BLKtest) then
       call set_oktest('user_sources',oktest,oktest_me)
    else
       oktest=.false.; oktest_me=.false.
    end if


    ! Compute Titan ionospheric source terms.
    !/

    do k = 1, nK ;   do j = 1, nJ ;  do i = 1, nI
       inv_rho = 1.00/State_VGB(rho_,i,j,k,globalBLK)
       inv_rho2 = inv_rho*inv_rho
       uu2 =(State_VGB(Ux_,i,j,k,globalBLK)*State_VGB(Ux_,i,j,k,globalBLK)  &
            +State_VGB(Uy_,i,j,k,globalBLK)*State_VGB(Uy_,i,j,k,globalBLK)  &
            +State_VGB(Uz_,i,j,k,globalBLK)*State_VGB(Uz_,i,j,k,globalBLK)) &
            *inv_rho2

       SrhoUx(i,j,k) = SrhoUx(i,j,k) &
            -nu_BLK(i,j,k,globalBLK)*State_VGB(Ux_,i,j,k,globalBLK)
       SrhoUy(i,j,k) = SrhoUy(i,j,k)  &
            -nu_BLK(i,j,k,globalBLK)*State_VGB(Uy_,i,j,k,globalBLK)
       SrhoUz(i,j,k) = SrhoUz(i,j,k)  &
            -nu_BLK(i,j,k,globalBLK)*State_VGB(Uz_,i,j,k,globalBLK)
       SE(i,j,k) = SE(i,j,k)  &
            -State_VGB(rho_,i,j,k,globalBLK)*uu2*nu_BLK(i,j,k,globalBLK) 

       ReactionRate_I=0.0
       CoeffSpecies_II(:,:)=0.0
       LossSpecies_I=0.0
       totalNumRho=0.0
       !          dStndRho_I=0.0
       !          dLtdRho_I=0
       !          dLtndNumRho_I=0
       SiSpecies_I(:)=0.0
       LiSpecies_I(:)=0.0
       do iSpecies=1, nSpecies
          totalNumRho=totalNumRho  &
               +State_VGB(rho_+iSpecies,i,j,k,globalBLK) &
               /MassSpecies_V(rho_+iSpecies)
       enddo

       if (R_BLK(i,j,k,globalBLK) >= Rbody) then

          !charge exchange


          ReactionRate_I(Lp_CH4__H1p_X_ )= &
               Rate_I(Lp_CH4__H1p_X_ )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,CH4_)
          CoeffSpecies_II(H1p_,Lp_)=ReactionRate_I(Lp_CH4__H1p_X_ )

          ReactionRate_I(Lp_N2__Mp_X_ )= &
               Rate_I(Lp_N2__Mp_X_ )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,N2_)
          CoeffSpecies_II(Mp_,Lp_)=ReactionRate_I(Lp_N2__Mp_X_ )

          ReactionRate_I(Mp_CH4__H2p_X_ )= &
               Rate_I( Mp_CH4__H2p_X_ )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,CH4_)
          CoeffSpecies_II(H2p_,Mp_)=ReactionRate_I(Mp_CH4__H2p_X_)

          ReactionRate_I(Mp_C2H4__H1p_X_  )= &
               Rate_I(Mp_C2H4__H1p_X_  )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,C2H4_)
          ReactionRate_I(Mp_C2H6__H1p_X_  )= &
               Rate_I(Mp_C2H6__H1p_X_  )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,C2H6_)
          CoeffSpecies_II(H1p_,Mp_)=ReactionRate_I(Mp_C2H6__H1p_X_  )&
               +ReactionRate_I(Mp_C2H4__H1p_X_  )


          ReactionRate_I(H1p_HCN__H2p_X_   )= &
               Rate_I(H1p_HCN__H2p_X_  )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,HCN_)
          CoeffSpecies_II(H2p_,H1p_)=ReactionRate_I(H1p_HCN__H2p_X_ )

          ReactionRate_I(H1p_HC3N__HNIp_X_    )= &
               Rate_I(H1p_HC3N__HNIp_X_   )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,HC3N_)
          CoeffSpecies_II(HNIp_,H1p_)=ReactionRate_I(H1p_HC3N__HNIp_X_ )

          ReactionRate_I( H1p_C2H2__MHCp_X_  )= &
               Rate_I(H1p_C2H2__MHCp_X_  )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,C2H2_)
          ReactionRate_I(H1p_C2H4__MHCp_X_   )= &
               Rate_I(H1p_C2H4__MHCp_X_  )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,C2H4_)
          CoeffSpecies_II(MHCp_,H1p_)=ReactionRate_I(H1p_C2H4__MHCp_X_ )&
               +ReactionRate_I(H1p_C2H2__MHCp_X_ )

          ReactionRate_I(H2p_HC3N__HNIp_X_   )= &
               Rate_I(H2p_HC3N__HNIp_X_  )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,HC3N_)
          CoeffSpecies_II(HNIp_,H2p_)=ReactionRate_I(H2p_HC3N__HNIp_X_ )

          ReactionRate_I( H2p_C4H2__MHCp_X_  )= &
               Rate_I(H2p_C4H2__MHCp_X_  )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,C4H2_)
          CoeffSpecies_II(MHCp_,H2p_)=ReactionRate_I(H2p_C4H2__MHCp_X_  )

          ReactionRate_I( MHCp_C2H2__HHCp_X_  )= &
               Rate_I(MHCp_C2H2__HHCp_X_  )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,C2H2_)
          ReactionRate_I( MHCp_C2H4__HHCp_X_)= &
               Rate_I(MHCp_C2H4__HHCp_X_ )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,C2H4_)
          ReactionRate_I(MHCp_C3H4__HHCp_X_  )= &
               Rate_I(MHCp_C3H4__HHCp_X_  )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,C3H4_)
          ReactionRate_I(MHCp_C4H2__HHCp_X_ )= &
               Rate_I(MHCp_C4H2__HHCp_X_ )&
               * nDenNuSpecies_CBI(i,j,k,globalBLK,C4H2_)
          CoeffSpecies_II(HHCp_,MHCp_)=ReactionRate_I(MHCp_C2H2__HHCp_X_  )&
               +ReactionRate_I( MHCp_C2H4__HHCp_X_)&
               +ReactionRate_I(MHCp_C3H4__HHCp_X_)&
               +ReactionRate_I(MHCp_C4H2__HHCp_X_)

          ! Recombination
          !end if  !(x>0.0)

          do iSpecies=1, nSpecies
             LossSpecies_I=LossSpecies_I &
                  +CoeffSpecies_II(iSpecies, :)
             !                dStndRho_I=dStndRho_I  &
                  !                     +CoeffSpecies_II(iSpecies, :)/MassSpecies_V(:)
             dSdRho_II(1:nSpecies, iSpecies)= &
                  CoeffSpecies_II(1:nSpecies, iSpecies)&
                  *MassSpecies_V(rho_+1:rho_+nSpecies)&
                  /MassSpecies_V(rho_+iSpecies)

          enddo

!!!              do iSpecies=1, nSpecies
!!!                 dLdRho_II(1:nSpecies, iSpecies)=Recb_I(1:nSpecies)&
!!!                      *rhoSpecies_GBI(i,j,k,globalBLK,1:nSpecies) &
!!!                      /MassSpecies_V(iSpecies)
!!!                 dLdRho_II(iSpecies, iSpecies)=  &
!!!                      dLdRho_II(iSpecies, iSpecies) &
!!!                      +LossSpecies_I(iSpecies)  &
!!!                      +Recb_I(iSpecies)*totalNumRho
!!!              enddo
!!!              !              dSLdRho_II=dSdRho_II-dLdRho_II
!!!
!!!              do iSpecies=1, nSpecies
!!!                 dLtdRho_I(:)=dLtdRho_I(:) +dLdRho_II(iSpecies,:)
!!!                 dLtndNumRho_I(:)=dLtndNumRho_I(:) &
!!!                      +dLdRho_II(iSpecies,:)*MassSpecies_V(:)/MassSpecies_V(iSpecies)
!!!              enddo              

          SiSpecies_I(:)=PhoIon_I(i,j,k,globalBLK,:)*MassSpecies_V(:)

          do iSpecies=1, nSpecies
             SiSpecies_I(1:nSpecies)=&
                  SiSpecies_I(1:nSpecies)  &
                  +dSdRho_II(1:nSpecies, iSpecies) &
                  *State_VGB(rho_+iSpecies, i,j,k, globalBLK)
             LiSpecies_I(iSpecies)= &
                  LiSpecies_I(iSpecies)+(LossSpecies_I(iSpecies) &
                  +Recb_I(i,j,k,globalBLK,iSpecies)*totalNumRho)&
                  *State_VGB(rho_+iSpecies, i,j,k, globalBLK)
          enddo


          totalLossRho=sum(LiSpecies_I(1:nSpecies))    
          !sum of the (Loss term) of all ion species
          totalSourceRho=sum(SiSpecies_I(1:nSpecies))    
          !sum of the (Source term) of all ion species
          totalLossNumRho=sum(LiSpecies_I(1:nSpecies)&
               /MassSpecies_V(SpeciesFirst_:SpeciesLast_))   
          !sum of the (loss term/atom mass) of all ..
          totalSourceNumRho=sum(SiSpecies_I(1:nSpecies)&
               /MassSpecies_V(SpeciesFirst_:SpeciesLast_))
          ! sum of the (Source term/atom mass) of all..
          totalLossx=totalLossRho*inv_rho
          totalLossNumx=totalLossNumRho/totalNumRho
          totalPSNumRho=sum(PhoIon_I(i,j,k,globalBLK,:)) 
          ! sum of the photonionziation source/atom mass) of all..
          totalRLNumRhox=sum(Recb_I(i,j,k,globalBLK,:) &
               *State_VGB(rho_+1:rho_+nSpecies, i,j,k, globalBLK)/MassSpecies_V(:))
          !sum of the (loss term/atom mass) due to recombination



          MaxSLSpecies_CB(i,j,k,globalBLK)=maxval(abs(SiSpecies_I(1:nSpecies)+&
               LiSpecies_I(1:nSpecies) ) /&
               (State_VGB(rho_+1:rho_+nSpecies, i,j,k, globalBLK)+1e-20))&
               /vInv_CB(i,j,k,globalBLK)

          VdtFace_x(i,j,k) = max (3.0*MaxSLSpecies_CB(i,j,k,globalBLK),&
               VdtFace_x(i,j,k) )
          VdtFace_y(i,j,k) = max (3.0*MaxSLSpecies_CB(i,j,k,globalBLK),&
               VdtFace_y(i,j,k) )
          VdtFace_z(i,j,k) = max (3.0*MaxSLSpecies_CB(i,j,k,globalBLK),&
               VdtFace_z(i,j,k) )

          SrhoSpecies(1:nSpecies,i,j,k)=SrhoSpecies(1:nSpecies,i,j,k)&
               +SiSpecies_I(1:nSpecies) &
               -LiSpecies_I(1:nSpecies)

          Srho(i,j,k)=Srho(i,j,k)&
               +sum(SiSpecies_I(1:MaxSpecies))&
               -sum(LiSpecies_I(1:MaxSpecies))

          SrhoUx(i,j,k) = SrhoUx(i,j,k) &
               -State_VGB(Ux_,i,j,k,globalBLK)*totalLossx  

          SrhoUy(i,j,k) = SrhoUy(i,j,k)  &
               -State_VGB(Uy_,i,j,k,globalBLK)*totalLossx 

          SrhoUz(i,j,k) = SrhoUz(i,j,k)  &
               -State_VGB(Uz_,i,j,k,globalBLK)*totalLossx 

          !           SE(i,j,k) = SE(i,j,k)  &
               !                +inv_gm1*totalSourceNumRho*XiT0 &
          !                -0.50*uu2*(totalLossRho) &
               !                -inv_gm1*totalLossNumx*State_VGB(P_,i,j,k,globalBLK) 

          SE(i,j,k) = SE(i,j,k)  &
               +inv_gm1*totalSourceNumRho*XiT0 &
               -0.50*uu2*(totalLossRho) &
               -inv_gm1*totalLossNumx*State_VGB(p_,i,j,k,globalBLK)

          SP(i,j,k) = SP(i,j,k)  &
               -0.5*State_VGB(rho_,i,j,k,globalBLK)*uu2*&
               nu_BLK(i,j,k,globalBLK)  &
               +inv_gm1*totalSourceNumRho*XiT0 &
               +0.50*uu2*(totalSourceRho) &
               -inv_gm1*totalLossNumx*State_VGB(p_,i,j,k,globalBLK)

       endif !R_BLK(i,j,k,globalBLK) >= Rbody?
    end do; end do; end do     ! end of the i,j,k loop
       if(oktest_me)then
          write(*,*)'rhosp=',State_VGB(rho_:8,itest,jtest,ktest,globalBLK)
          write(*,*)'srhoUx=', SrhoUx(itest,jtest,ktest), &
               'srhoUy=', SrhoUy(itest,jtest,ktest),&
               'srhoUz=', SrhoUz(itest,jtest,ktest)
          write(*,*)'state_VGB(u)=',&
               State_VGB(Ux_:Uz_,itest,jtest,ktest,globalBLK) 
          write(*,*)'state_VGB(B)=',&
               State_VGB(Bx_:Bz_,itest,jtest,ktest,globalBLK) 
          write(*,*)'state_VGB(P)=',&
               State_VGB(p_,itest,jtest,ktest,globalBLK) 

       end if

  end subroutine user_sources

  !==============================================================================
  subroutine user_init_session
    use ModMain, ONLY:BODY1_
    use ModPhysics
    use ModVarIndexes, ONLY: ScalarFirst_,ScalarLast_, &
         rhoUx_, rhoUz_,  UNITUSER_V
    integer::iBoundary
    !--------------------------------------------------------------------------
    !For Outer Boundaries
!    if(UseMultiSpecies)then
!       SW_rho_dim = Plas_rho
!       SW_T_dim = plas_T      
!    end if
!    unitUSER_n=SW_rho_dim
    do iBoundary=East_,Top_
       FaceState_VI(ScalarFirst_:ScalarLast_,iBoundary)  = cTiny8/1.0e5     
     !  FaceState_VI(ScalarFirst_:ScalarLast_,iBoundary)  = 0.0
       FaceState_VI(RhoLp_,iBoundary)=SW_LP
       FaceState_VI(RhoMp_,iBoundary)=SW_MP
       FaceState_VI(Rho_,iBoundary)=FaceState_VI(RhoLp_,iBoundary)+&
            FaceState_VI(RhoMp_,iBoundary)
    end do
    call set_multiSp_ICs  
    !    Rbody = 1.0 + 725.0e3/RTitan
    Body_rho= sum(BodyRhoSpecies_I(1:nSpecies))
    Body_p=max(sw_p,SW_p*sum(BodyRhoSpecies_I(1:nSpecies)&
         /MassSpecies_V(SpeciesFirst_:SpeciesLast_))*Body_Ti_dim/SW_T_dim)
    FaceState_VI(rho_,body1_)=Body_rho
    FaceState_VI(ScalarFirst_:ScalarLast_,body1_) = BodyRhoSpecies_I
    FaceState_VI(P_,body1_)=Body_p
    CellState_VI(:,body1_:Top_)=FaceState_VI(:,body1_:Top_)
    do iBoundary=body1_,Top_  
       CellState_VI(rhoUx_:rhoUz_,iBoundary) = &
            FaceState_VI(Ux_:Uz_,iBoundary)*FaceState_VI(rho_,iBoundary)
    end do
!    write(*,*)'CellState_VI, body1_=',CellState_VI(:,body1_)
!    write(*,*)'CellState_VI, top_=',CellState_VI(:,Top_)
!    write(*,*)'CellState_VI, east_=',CellState_VI(:,East_)    
    unitUSER_V(ScalarFirst_:ScalarLast_)   = unitUSER_rho/MassSpecies_V
  end subroutine user_init_session


  !========================================================================
  !  SUBROUTINE USER_SET_ICs
  ! (It will include set_ICs_global.f90
  !!\
  ! Calculates the initial conditions of the grid for the Global Heliosphere
  !
  ! Written by Merav Opher Feb 14  2002
  !/
  ! OMEGAbody is the rotation frequency of the Sun
  !========================================================================

  ! This subroutine allows the user to apply initial conditions to the domain
  ! which are problem specific and cannot be created using the predefined
  ! options in BATSRUS.
  ! The variables specific to the problem are loaded from ModUser

  subroutine user_set_ICs
    use ModProcMH, ONLY : iProc
    use ModMain, ONLY: GlobalBLK, Body1_, ProcTest
    use ModAdvance
    use ModGeometry, ONLY : x2,y2,z2,x_BLK,y_BLK,z_BLK,R_BLK,true_cell
    use ModIO, ONLY : restart
    use ModPhysics


    real :: Rmax, SinSlope, CosSlope,CosSZA, coef, hh
    real :: B4, dB4dx, zeta4, q4, epsi4, plobe, &
         XFace, YFace, ZFace
    integer :: i,j,k,n
    integer:: iBoundary
    !-------------------------------------------------------------------------

    if(UseMultiSpecies) then
       if(UseTitaninput)call Titan_input
    end if

    if(.not.restart)then
       !\
       ! Initialize solution quantities.
       !/

       do k=1-gcn,nK+gcn;do j=1-gcn,nJ+gcn; do i=1-gcn,nI+gcn
          if (R_BLK(i,j,k,globalBLK)< Rbody) then
             State_VGB(:,i,j,k,globalBLK)   =  CellState_VI(:,body1_)
          else
             State_VGB(:,i,j,k,globalBLK)   = CellState_VI(:,1)
             State_VGB(Bx_:Bz_,i,j,k,globalBLK)=0.0
          end if
       end do;end do; end do;

       do k=1-gcn,nK+gcn; do j=1-gcn,nJ+gcn; do i=1-gcn,nI+gcn
          cosSZA=(x_BLK(i,j,k,globalBLK)*SX0 &
               + y_BLK(i,j,k,globalBLK)*SY0 &
               + z_BLK(i,j,k,globalBLK)*SZ0)&
               /max(R_BLK(i,j,k,globalBLK),1.0e-3)
          coef=2.0*cosSZA
          if(cosSZA.lt.0.5)then
             coef =1.001+2.0/3.0*(cosSZA-0.5)
          end if
          if (R_BLK(i,j,k,globalBLK)< Rbody)then
             State_VGB(rho_+1:rho_+nSpecies,i,j,k,globalBLK)=&
                  BodyRhoSpecies_I(1:nSpecies)*coef
          else
             hh = (R_BLK(i,j,k,globalBLK)-1.00)*2575.0
             n= int((hh -725.0)/10.0+1.0)

             if(n<1) then 
                n=1
             else if(n> num_Ri-1) then
                n = num_Ri-1
             end if
             State_VGB(rho_+1:rho_+nSpecies,i,j,k,globalBLK)=&
                  tmp_ion(:,n)+&
                  (tmp_ion(:,n+1)-tmp_ion(:,n))*&
                  (hh-tmp_hR(n))/(tmp_hR(n+1)-tmp_hR(n))

             State_VGB(SpeciesFirst_:SpeciesLast_,i,j,k,globalBLK)= &
                  State_VGB(SpeciesFirst_:SpeciesLast_,i,j,k,globalBLK)&
                  *coef*MassSpecies_V(SpeciesFirst_:SpeciesLast_)/unitUSER_n

             State_VGB(SpeciesFirst_:SpeciesLast_,i,j,k,globalBLK)=&
                  max(0.0,State_VGB(SpeciesFirst_:SpeciesLast_,i,j,k,globalBLK))
             State_VGB(rhoLp_,i,j,k,globalBLK)= SW_Lp
             State_VGB(rhoMp_,i,j,k,globalBLK)=&
                  State_VGB(rhoMp_,i,j,k,globalBLK)*&
                  (Rbody/R_BLK(i,j,k,globalBLK))**2+ &
                  SW_Mp

          end if

          State_VGB(rho_,i,j,k,globalBLK)   =&
               sum(State_VGB(rho_+1:rho_+MaxSpecies,i,j,k,globalBLK))
          State_VGB(ux_:uz_,i,j,k,globalBLK)   = 0.0
!&
!               CellState_VI(ux_:Uz_,1)/CellState_VI(rho_,1)&
!               *State_VGB(rho_,i,j,k,globalBLK)
          State_VGB(P_,i,j,k,globalBLK)= &
               sum(State_VGB(SpeciesFirst_:SpeciesLast_,i,j,k,globalBLK)&
               /MassSpecies_V(SpeciesFirst_:SpeciesLast_))*XiT0          
          if(R_BLK(i,j,k,globalBLK).gt.2.0)&
               State_VGB(P_,i,j,k,globalBLK)= &
               max(SW_p, State_VGB(P_,i,j,k,globalBLK))

       end do; end do; end do

       time_BLK(:,:,:,globalBLK) = 0.00

    end if

  end subroutine user_set_ICs

  !========================================================================
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !THIS SUBROUTINE calculate the scale height of ion and neutal species and 
  !intial boundary value of ion species
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  subroutine set_multiSp_ICs
    use ModMain
    use ModConst
    use ModIO
    use ModPhysics
    real :: Productrate
    !---------------------------------------------------------------

    cos_ISZA=cos(SZATitan*cPi/180.0)
    body_Ti_dim = 350
    XiT0 = SW_p*body_Ti_dim/SW_T_dim
    nu0_dim =  1.0e-10
    nu0=nu0_dim*unitUSER_n*unitUSER_t

    Ratedim_I(M_hv__Mp_em_ )=1.0   !1
    Ratedim_I(H1_hv__H1p_em_)=1.0  !2
    Ratedim_I(L_hv__Lp_em_)=1.0    !3
    Ratedim_I(Lp_em__L_)=3.5e-12   !4
    Ratedim_I(Mp_em__M_)=7.0e-7    !5 
    Ratedim_I(H1p_em__H1_)=1.9e-6
    Ratedim_I(H2p_em__H2_)=6.4e-7
    Ratedim_I(MHCp_em__MHC_)=1.0e-6
    Ratedim_I(HHCp_em__HHC_)=1.0e-6
    Ratedim_I(HNIp_em__HNI_)=1.0e-6   !10
    Ratedim_I(Lp_CH4__H1p_X_)=1.3e-9
    Ratedim_I(Lp_N2__Mp_X_  )=4.0e-10
    Ratedim_I(Mp_CH4__H2p_X_  )=1.0e-11
    Ratedim_I(Mp_C2H4__H1p_X_  )=1.5e-9
    Ratedim_I( Mp_C2H6__H1p_X_ )=2.0e-10 !15
    Ratedim_I(H1p_HCN__H2p_X_  )=2.7e-9
    Ratedim_I(H1p_HC3N__HNIp_X_  )=3.6e-9
    Ratedim_I(H1p_C2H2__MHCp_X_ )=1.0e-10
    Ratedim_I(H1p_C2H4__MHCp_X_  )=3.9e-10
    Ratedim_I(H2p_HC3N__HNIp_X_ )=3.4e-9   !20
    Ratedim_I(H2p_C4H2__MHCp_X_  )=1.6e-9
    Ratedim_I(MHCp_C2H2__HHCp_X_ )=4.0e-10
    Ratedim_I(MHCp_C2H4__HHCp_X_ )=2.0e-10
    Ratedim_I(MHCp_C3H4__HHCp_X_ )=6.0e-10
    Ratedim_I(MHCp_C4H2__HHCp_X_ )=4.0e-10  !25

    ion_name_I(Lp_ ) ='Lp  '
    ion_name_I(Mp_ ) ='Mp  '
    ion_name_I(H1p_ ) ='H1p  '
    ion_name_I(H2p_ ) ='H2p  '
    ion_name_I(MHCp_ ) ='MHCp  '
    ion_name_I(HHCp_ ) ='HHCp  '
    ion_name_I(HNIp_ ) ='HNIp  '

    BodynDenNuSpdim_I(:)=tmp_n(1:nNuSpecies,1)
    BodynDenNuSpecies_I(1:nNuSpecies)=&
         BodynDenNuSpdim_I(1:nNuSpecies)/unitUSER_n

    Rate_I(4:25)=Ratedim_I(4:25)*unitUSER_t*unitUSER_n
    BodyRhoSpecies_I(:)=tmp_ion(1:nSpecies,1)*&
         MassSpecies_V(SpeciesFirst_:SpeciesLast_)/unitUSER_n
    !     write(*,*)'BodyRhoSpecies_I=',BodyRhoSpecies_I,&
    !'unit_usern=',unitUSER_n
    !     write(*,*)'temp_ion=',tmp_ion(1:nSpecies,1)

  end subroutine set_multiSp_ICs

  !========================================================================
  !========================================================================
  subroutine user_update_states(iStage,iBlock)
    use ModAdvance, ONLY: State_VGB, E_BLK
!    use ModProcMH
    use ModPhysics, ONLY: cTiny8, gm1, cHalf
    use ModVarIndexes, ONLY: rhoUx_, rhoUy_, rhoUz_
    integer,intent(in):: iStage,iBlock
    integer::i,j,k
    !--------------------------------------------------------------------------
    call update_states_MHD(iStage,iBlock)
    !\
    ! Begin update of total density
    !/

    do k=1,nK; do j=1,nJ; do i=1,nI
       State_VGB(rho_+1:rho_+maxspecies,i,j,k,iBlock)=           &
            max(cTiny8/1.0e5, State_VGB(rho_+1:rho_+MaxSpecies,i,j,k,iBlock))

       State_VGB(rho_   ,i,j,k,iBlock)=           &
            sum(State_VGB(rho_+1:rho_+MaxSpecies,i,j,k,iBlock))

    end do; end do; end do

    State_VGB(P_,1:nI,1:nJ,1:nK,iBlock) = gm1*(&
         E_BLK(1:nI,1:nJ,1:nK,iBlock) &
         - cHalf*((State_VGB(rhoUx_,1:nI,1:nJ,1:nK,iBlock)**2 +&
         State_VGB(rhoUy_,1:nI,1:nJ,1:nK,iBlock)**2 +&
         State_VGB(rhoUz_,1:nI,1:nJ,1:nK,iBlock)**2) &
         /State_VGB(rho_,1:nI,1:nJ,1:nK,iBlock)  &
         +   State_VGB(Bx_,1:nI,1:nJ,1:nK,iBlock)**2 + &
         State_VGB(By_,1:nI,1:nJ,1:nK,iBlock)**2 + &
         State_VGB(Bz_,1:nI,1:nJ,1:nK,iBlock)**2) )
    
    !\
    ! End update of total density:
    !/

  end subroutine user_update_states

  !========================================================================

  !========================================================================
  !  user_set_boundary_cells
  !  Allows to define boundary conditions at the user defined boundary.
  !========================================================================
  subroutine user_set_boundary_cells(iBLK)
    use ModGeometry
    use ModMain, ONLY: Theta_ 	
    use ModNumConst	

    integer,intent(in)::iBLK
    !-----------------------------------------------------------------------
    !  SHOULD define IsBoundaryCell_GI(:,:,:,ExtraBc_) using
    !  a boundary condition for iBLK block
    !  EXAMPLE: OUTER SPHERICAL BOUNDARY of radius of 100.
    !  IsBoundaryCell_GI(:,:,:,ExtraBc_) = R_BLK(:,:,:,iBLK)<100.
    if (index(TypeGeometry,'spherical')>0)then
       if(XyzStart_BLK(Theta_,iBLK)<dz_BLK(iBLK))then
          !	IsBoundaryCell_GI(:,:,1-gcn:0,ExtraBc_)=.true.
          !	IsBoundaryCell_GI(1:nI,1:nJ,1-gcn:0,ExtraBc_)=.false.

          !	IsBoundaryCell_GI(:,:,1-gcn:0,ExtraBc_)=.true.
          IsBoundaryCell_GI(nI+1:nI+gcn,:,1-gcn:0,ExtraBc_)=.true.
          IsBoundaryCell_GI(1-gcn:0,:,1-gcn:0,ExtraBc_)=.true.	
       elseif(XyzStart_BLK(Theta_,iBLK)+nK*dz_BLK(iBLK)>cPi)then
          !        IsBoundaryCell_GI(:,:,nK+1:nK+gcn,ExtraBc_)=.true.
          !        IsBoundaryCell_GI(1:nI,1:nJ,nK+1:nK+gcn,ExtraBc_)=.false.

          !        IsBoundaryCell_GI(:,:,nK+1:nK+gcn,ExtraBc_)=.true.
          IsBoundaryCell_GI(nI+1:nI+gcn,:,nK+1:nK+gcn,ExtraBc_)=.true.
          IsBoundaryCell_GI(1-gcn:0,:,nK+1:nK+gcn,ExtraBc_)=.true.
       end if
    end if
  end subroutine user_set_boundary_cells
  !========================================================================

  !========================================================================
  !  SUBROUTINE USER_SET_INNER_BCS
  !========================================================================
  !\
  ! This subroutine allows the user to apply boundary conditions to the inner
  ! body which are problem specific and cannot be created using the predefined
  ! options in BATSRUS.  The available options in BATSRUS have been designed
  ! to be self consistent and reasonably robust.  We generally recommend that
  ! you use on of those or a variant that is very close to one of them.  They
  ! can be considered reasonably safe.
  !
  ! An example of a reasonable variant would be to use a modification of the
  ! "ionosphere" boundary where the density is fixed at the boundary to a 
  ! value that is a function of latitude.
  !
  ! This routine is called for a single inner boundary face.  Since BATSRUS is
  ! is block cartesian, the values inside the boundary face must be passed back
  ! in cartesian coordinates.  Values that must be set are:
  !
  !  RhoFaceInside, pFaceInside, VxFaceInside, VyFaceInside, VzFaceInside
  !  BxFaceInside, ByFaceInside, BzFaceInside, EwFaceInside
  !
  ! Typically the boundary conditions are applied for the spherical coordinates
  ! and then transformed to the cartesian ones.
  !
  ! As with all user subroutines, the variables declared in ModUser are 
  ! available here.  Again, as with other user subroutines DO NOT MODIFY 
  ! ANY GLOBAL VARIABLE DEFINED IN THE MODULES INCLUDED IN THIS SUBROUTINE 
  ! UNLESS SPECIFIED!!
  !/
  subroutine user_face_bcs(iFace,jFace,kFace,iBlock,iSide,iBoundary, &
       iter,time_now,FaceCoords_D,VarsTrueFace_V,VarsGhostFace_V,    &
       B0Face_D,UseIonosphereHere,UseRotatingBcHere)
    use ModSize,     ONLY: nDim,West_,North_,Top_	
    use ModMain
    use ModAdvance,  ONLY: nFaceValueVars
    use ModPhysics,  ONLY: g,inv_g,cosTHETAtilt,sinTHETAtilt, SW_rho, SW_p, SW_T_dim
    use ModNumConst, ONLY: cZero,cOne,cTwo,cTolerance
    !--------------------------------------------------------------------------

    !\
    ! Variables required by this user subroutine
    !/
    integer, intent(in):: iFace,jFace,kFace,iBlock,iSide,&
         iBoundary,iter
    real, intent(in):: time_now
    real, dimension(nDim), intent(in):: FaceCoords_D,    &
         B0Face_D
    real, dimension(nFaceValueVars), intent(in)::        &
         VarsTrueFace_V
    logical, intent(in):: UseIonosphereHere,             &
         UseRotatingBcHere
    real, dimension(nFaceValueVars), intent(out)::       &
         VarsGhostFace_V
    !\
    ! User declared local variables go here::
    !/
    real:: XFace,YFace,ZFace
    real:: VxFaceOutside,VyFaceOutside,VzFaceOutside
    real:: BxFaceOutside,ByFaceOutside,BzFaceOutside
    real:: VrFaceOutside,VthetaFaceOutside,VphiFaceOutside,&
         VrFaceInside,VthetaFaceInside,VphiFaceInside,     &
         BrFaceOutside,BthetaFaceOutside,BphiFaceOutside,  &
         BrFaceInside,BthetaFaceInside,BphiFaceInside
    real:: cosTheta,sinTheta,cosPhi,sinPhi,RFace
    real, dimension(1:3):: location,v_phi
    real:: XFaceT,YFaceT,ZFaceT,sin2Theta_coronal_hole
    real:: cosThetaT,sinThetaT,cosPhiT,sinPhiT
    real:: cosSZA, coef
    !--------------------------------------------------------------------------
    !
    !---------------------------------------------------------------------------
    !\
    ! Calculation of boundary conditions should start here::
    !/
    !---------------------------------------------------------------------------
    !
    XFace = FaceCoords_D(1)
    YFace = FaceCoords_D(2)
    ZFace = FaceCoords_D(3)
    VxFaceOutside = VarsTrueFace_V(Ux_)
    VyFaceOutside = VarsTrueFace_V(Uy_)
    VzFaceOutside = VarsTrueFace_V(Uz_)
    BxFaceOutside = VarsTrueFace_V(Bx_)
    ByFaceOutside = VarsTrueFace_V(By_)
    BzFaceOutside = VarsTrueFace_V(Bz_)
    !\
    ! Rotate to spherical coordinates
    !/
    RFace    = sqrt(XFace**2+YFace**2+ZFace**2)
    cosTheta = ZFace/RFace
    sinTheta = sqrt(XFace**2+YFace**2)/RFace
    cosPhi   = XFace/sqrt(XFace**2+YFace**2+cTolerance**2)
    sinPhi   = YFace/sqrt(XFace**2+YFace**2+cTolerance**2)
    VrFaceOutside = (VxFaceOutside*XFace      +&
         VyFaceOutside*YFace                  +&
         VzFaceOutside*ZFace)/RFace
    VthetaFaceOutside = ((VxFaceOutside*XFace +&
         VyFaceOutside*YFace)*ZFace           -&
         VzFaceOutside*(XFace**2+YFace**2))   /&
         (sqrt(XFace**2+YFace**2+cTolerance**2)*RFace)
    VphiFaceOutside = (VyFaceOutside*XFace    -&
         VxFaceOutside*YFace)*sinTheta        /&
         ((XFace**2+YFace**2+cTolerance**2)/RFace)
    BrFaceOutside = (BxFaceOutside*XFace      +&
         ByFaceOutside*YFace                  +&
         BzFaceOutside*ZFace)/RFace
    BthetaFaceOutside = ((BxFaceOutside*XFace +&
         ByFaceOutside*YFace)*ZFace           -&
         BzFaceOutside*(XFace**2+YFace**2))   /&
         (sqrt(XFace**2+YFace**2+cTolerance**2)*RFace)
    BphiFaceOutside = (ByFaceOutside*XFace    -&
         BxFaceOutside*YFace)*sinTheta        /&
         ((XFace**2+YFace**2+cTolerance**2)/RFace)


    !Apply boundary conditions
    select case(iBoundary)                                                 
    case(body1_)
       cosSZA=(XFace*SX0+YFace*SY0+ZFace*SZ0)&
            /max(RFace,1.0e-3)
       coef=2.0*cosSZA
       if(cosSZA.lt.0.5)then
          coef =1.001+2.0/3.0*(cosSZA-0.5)
       end if
       VarsGhostFace_V(rho_+1:rho_+nSpecies) = &
            BodyRhoSpecies_I(1:nSpecies)*coef

       VarsGhostFace_V(rho_) = sum(VarsGhostFace_V(rho_+1:rho_+nSpecies))
       VarsGhostFace_V(P_)=sum(VarsGhostFace_V(rho_+1:rho_+nSpecies)&
            /MassSpecies_V(SpeciesFirst_:SpeciesLast_))*SW_p*Body_Ti_dim/SW_T_dim

       VrFaceInside     = -VrFaceOutside
       VthetaFaceInside = VthetaFaceOutside
       VphiFaceInside   = VphiFaceOutside
       BrFaceInside     = -BrFaceOutside
       BthetaFaceInside = BthetaFaceOutside
       BphiFaceInside   = BphiFaceOutside
!       BrFaceInside     = cZero
!       BthetaFaceInside = cZero
!       BphiFaceInside   = cZero
    end select

    !\
    ! Rotate back to cartesian coordinates::
    !/
    VarsGhostFace_V(Ux_) = VrFaceInside*XFace/RFace+&
         VthetaFaceInside*cosTheta*cosPhi          -&
         VphiFaceInside*sinPhi 
    VarsGhostFace_V(Uy_) = VrFaceInside*YFace/RFace+&
         VthetaFaceInside*cosTheta*sinPhi          +&
         VphiFaceInside*cosPhi
    VarsGhostFace_V(Uz_) = VrFaceInside*ZFace/RFace-&
         VthetaFaceInside*sinTheta
    VarsGhostFace_V(Bx_) = BrFaceInside*XFace/RFace+&
         BthetaFaceInside*cosTheta*cosPhi          -&
         BphiFaceInside*sinPhi
    VarsGhostFace_V(By_) = BrFaceInside*YFace/RFace+&
         BthetaFaceInside*cosTheta*sinPhi          +&
         BphiFaceInside*cosPhi
    VarsGhostFace_V(Bz_) = BrFaceInside*ZFace/RFace-&
         BthetaFaceInside*sinTheta
    !\
    ! Apply corotation:: Currently works only for the first body.
    !/
    if (UseRotatingBcHere) then
       location(1) = XFace 
       location(2) = YFace 
       location(3) = ZFace
       !\
       ! The program is called which calculates the cartesian 
       ! corotation velocity vector v_phi as a function of the 
       ! radius-vector "location".
       !/
       call calc_corotation_velocities(iter,time_now,&
            location,v_phi)
       VarsGhostFace_V(Ux_) = VarsGhostFace_V(Ux_)  +&
            cTwo*v_phi(1)
       VarsGhostFace_V(Uy_) = VarsGhostFace_V(Uy_)  +&
            cTwo*v_phi(2)
       VarsGhostFace_V(Uz_) = VarsGhostFace_V(Uz_)  +&
            cTwo*v_phi(3)
    end if

  end subroutine user_face_bcs

  !====================================================================
  !                     neutral_density_averages
  !====================================================================
  subroutine neutral_density_averages
    use ModMain, ONLY: globalBLK 
    use ModGeometry, ONLY : x_BLK, y_BLK, z_BLK, true_cell,vInv_CB, R_BLK
    use ModNumConst, ONLY: cHalf,cTolerance
    use ModCovariant, ONLY : FaceAreaI_DFB, FaceAreaJ_DFB, FaceAreaK_DFB
    integer :: i,j,k,iNu
    real:: FaceArea_DS(3,east_:top_),VInv

    real ::  density_IS(6,nNuSpecies),x,y,z,R0, factor
    !real :: neutral_density
    !true_cell note: using true_cell to replace an Rbody test does not apply here
    !----------------------------------------------------------------

    do k=1,nK; do j=1,nJ;  do i=1,nI  
       VInv=vInv_CB(i,j,k,globalBLK)

       if(.not.true_cell(i,j,k,globalBLK))cycle
       !-------------------East----------------------------------
       x = cHalf*(x_BLK(i-1,j,k,globalBLK) + x_BLK(i,j,k,globalBLK))
       y = cHalf*(y_BLK(i-1,j,k,globalBLK) + y_BLK(i,j,k,globalBLK))
       z = cHalf*(z_BLK(i-1,j,k,globalBLK) + z_BLK(i,j,k,globalBLK))
       R0 = sqrt(x*x + y*y + z*z+cTolerance**2)
       FaceArea_DS(:,East_)= FaceAreaI_DFB(:,i,j,k,globalBLK)
       factor = (FaceArea_DS(1,East_)*x+ &
            FaceArea_DS(2,East_)*y+ &
            FaceArea_DS(3,East_)*z)/R0
       do iNu = 1, nNuSpecies 
          density_IS(East_,iNu) = neutral_density(R0,iNu)*factor
       end do

       !-------------------West----------------------------------
       x = cHalf*(x_BLK(i+1,j,k,globalBLK)+x_BLK(i,j,k,globalBLK))
       y = cHalf*(y_BLK(i+1,j,k,globalBLK)+y_BLK(i,j,k,globalBLK))
       z = cHalf*(z_BLK(i+1,j,k,globalBLK)+z_BLK(i,j,k,globalBLK))
       R0 = sqrt(x*x + y*y + z*z+cTolerance**2)
       FaceArea_DS(:,West_)= FaceAreaI_DFB(:,i+1,j,k,globalBLK)
       factor = (FaceArea_DS(1,West_)*x+ &
            FaceArea_DS(2,West_)*y+ &
            FaceArea_DS(3,West_)*z)/R0     
       do iNu = 1, nNuSpecies 
          density_IS(West_,iNu) =-neutral_density(R0,iNu)*factor
       end do

       !-------------------South----------------------------------
       x = cHalf*(x_BLK(i,j-1,k,globalBLK)+x_BLK(i,j,k,globalBLK))
       y = cHalf*(y_BLK(i,j-1,k,globalBLK)+y_BLK(i,j,k,globalBLK))
       z = cHalf*(z_BLK(i,j-1,k,globalBLK)+z_BLK(i,j,k,globalBLK))
       R0 = sqrt(x*x + y*y + z*z+cTolerance**2)
       FaceArea_DS(:,South_)=FaceAreaJ_DFB(:,i,j,k,globalBLK)
       factor = (FaceArea_DS(1,South_)*x+ &
            FaceArea_DS(2,South_)*y+ &
            FaceArea_DS(3,South_)*z)/R0  
       do iNu = 1, nNuSpecies 
          density_IS(South_,iNu) = neutral_density(R0,iNu)*factor
       end do

       !-------------------North----------------------------------
       x = cHalf*(x_BLK(i,j+1,k,globalBLK)+x_BLK(i,j,k,globalBLK))
       y = cHalf*(y_BLK(i,j+1,k,globalBLK)+y_BLK(i,j,k,globalBLK))
       z = cHalf*(z_BLK(i,j+1,k,globalBLK)+z_BLK(i,j,k,globalBLK))
       R0 = sqrt(x*x + y*y + z*z+cTolerance**2)
       FaceArea_DS(:,North_)=FaceAreaJ_DFB(:,i,j+1,k,globalBLK)
       factor = (FaceArea_DS(1,North_)*x+ &
            FaceArea_DS(2,North_)*y+ &
            FaceArea_DS(3,North_)*z)/R0     
       do iNu = 1, nNuSpecies 
          density_IS(North_,iNu) = -neutral_density(R0,iNu)*factor
       end do

       !-------------------Bot----------------------------------
       x = cHalf*(x_BLK(i,j,k-1,globalBLK)+x_BLK(i,j,k,globalBLK))
       y = cHalf*(y_BLK(i,j,k-1,globalBLK)+y_BLK(i,j,k,globalBLK))
       z = cHalf*(z_BLK(i,j,k-1,globalBLK)+z_BLK(i,j,k,globalBLK))
       R0 = sqrt(x*x + y*y + z*z+cTolerance**2)
       FaceArea_DS(:,Bot_)= FaceAreaK_DFB(:,i,j,k,globalBLK)
       factor = (FaceArea_DS(1,Bot_)*x+ &
            FaceArea_DS(2,Bot_)*y+ &
            FaceArea_DS(3,Bot_)*z)/R0
       do iNu = 1, nNuSpecies 
          density_IS(Bot_,iNu) = neutral_density(R0,iNu)*factor
       end do

       !-------------------Top----------------------------------
       x = cHalf*(x_BLK(i,j,k+1,globalBLK)+x_BLK(i,j,k,globalBLK))
       y = cHalf*(y_BLK(i,j,k+1,globalBLK)+y_BLK(i,j,k,globalBLK))
       z = cHalf*(z_BLK(i,j,k+1,globalBLK)+z_BLK(i,j,k,globalBLK))
       R0 = sqrt(x*x + y*y + z*z+cTolerance**2)
       FaceArea_DS(:,Top_)= FaceAreaK_DFB(:,i,j,k+1,globalBLK)
       factor = (FaceArea_DS(1,Top_)*x+ &
            FaceArea_DS(2,Top_)*y+ &
            FaceArea_DS(3,Top_)*z)/R0 
       do iNu = 1, nNuSpecies 
          density_IS(Top_,iNu) = -neutral_density(R0,iNu)*factor
       end do

       !-------------------SUM----------------------------------
       do iNu = 1, nNuSpecies 
          nDenNuSpecies_CBI(i,j,k,globalBLK,iNu)=VInv* &
               sum(density_IS(:,iNu))&
               *HNuSpecies_I(iNu)*BodynDenNuSpecies_I(iNu)
          if(nDenNuSpecies_CBI(i,j,k,globalBLK,iNu)<0)then
             write(*,*)'wrong sign, i,j,k,golablBLK, iNu',&
                  i,j,k,globalBLK,iNu, R_BLK(i,j,k,globalBLK)
          end if
       end do

    end do; end do ;end do 

  end subroutine neutral_density_averages

  !==============================================================================
  real function neutral_density(R0,iNu)
    use ModPhysics, ONLY :Rbody,cZero

    real, intent(in) :: R0
    integer, intent(in) :: iNu

    !-----------------------------------------------------------------------
    neutral_density = cZero
    if( R0 >= 0.9*Rbody .and. R0< 3.0*Rbody ) &
         neutral_density= exp(-(R0-Rbody)/HNuSpecies_I(iNu))

  end function neutral_density
  !=============================================================================
  subroutine Titan_Input
    use ModMain, ONLY: GLOBALBLK
    use ModPhysics
    use ModGeometry

    !-----------------------------------------------------------------------  
    !  integer, parameter :: num_Te = 9500, num_Ri = 9496, num_n = 9500
    real, parameter :: TINY=1.0E-4 
    !  real, dimension(1:num_n) :: tmp_rn, tmp_hn, tmp_nL, tmp_nM, tmp_nH
    !  real, dimension(1:num_Te) :: tmp_hT, tmp_Te
    !  real, dimension(1:num_Ri) :: tmp_hR, tmp_RL0, tmp_RM0,tmp_RH0
    real, dimension(1:nI,1:nJ,1:nK,nBLK) :: Te_BLK, nL_BLK, nM_BLK, nH_BLK, &
         RM0_BLK, RH0_BLK, RL0_BLK 
    real :: hh, cosS0, dhn,dhnp1, dtm, dtmp1
    integer :: i,j,k,n, m

    !------ Interpolation/Expolation for Te,nL,nM,nH,RM0,RH0 ----- 
    !------ Original data units are as follows -----------------
    !Radius (km)     Number Density (cm^-3)
    !                 Light   Med.   Heavy
    !---------------------------------------


    !Altitude (km)       Te (k)
    !---------------------------------------


    !Altitude (km)   Ion Prod. Rates (cm^-3 S^-1)
    !                  Light   Med.   Heavy
    !---------------------------------------


!!!!!-------------------------- Interpolation/Expolation for Te -------------------------
    !     open(1,file="T_e.dat",status="old")
    !     read(1,*) (tmp_hT(i),tmp_Te(i),i=1,num_Te)
    !     close(1)
    Te_BLK(:,:,:,globalBLK) = 0.00
    Recb_I(:,:,:,globalBLK,:)= 0.00
    !     do globalBLK = 1,nBlockMax
    do k=1,nK
       do j=1,nJ
          do i=1,nI
             if (R_BLK(i,j,k,globalBLK) >= Rbody) then
                hh = (R_BLK(i,j,k,globalBLK)-1.00)*2575.0
                do n=1,num_Te-1
                   if ((hh <= tmp_hT(n+1)) .and. (hh >= tmp_hT(n))) then
                      Te_BLK(i,j,k,globalBLK) = tmp_Te(n) + (tmp_Te(n+1)-tmp_Te(n))*(hh-tmp_hT(n))/ &
                           (tmp_hT(n+1)-tmp_hT(n))
                   end if
                end do
                if (hh < tmp_hT(1)) then
                   Te_BLK(i,j,k,globalBLK) = tmp_Te(1) + (tmp_Te(1)-tmp_Te(2))* &
                        (tmp_hT(1)-hh)/(tmp_hT(2)-tmp_hT(1))
                end if
                if (hh > tmp_hT(num_Te)) then
                   Te_BLK(i,j,k,globalBLK) = tmp_Te(num_Te) 
                end if
                if (Te_BLK(i,j,k,globalBLK) < 0.00)&
                     Te_BLK(i,j,k,globalBLK) = 200.0

                Recb_I(i,j,k,globalBLK,Lp_)=Rate_I(Lp_em__L_ )

                Recb_I(i,j,k,globalBLK,Mp_)=Rate_I(Mp_em__M_ )

                Recb_I(i,j,k,globalBLK,H1p_)=Rate_I(H1p_em__H1_ )

                Recb_I(i,j,k,globalBLK,H2p_)=Rate_I(H2p_em__H2_ )

                Recb_I(i,j,k,globalBLK,MHCp_)=Rate_I(MHCp_em__MHC_ )

                Recb_I(i,j,k,globalBLK,HHCp_)=Rate_I(HHCp_em__HHC_ )

                Recb_I(i,j,k,globalBLK,HNIp_)=Rate_I(HNIp_em__HNI_ )

                Recb_I(i,j,k,globalBLK,:)=Recb_I(i,j,k,globalBLK,:)&
                     *sqrt(300.0/Te_BLK(i,j,k,globalBLK))

                !                    write(*,*)'i,j,k,globalBLK=',i,j,k,globalBLK,Rate_I(mep_em__me_),Rate_I(hap_em__ha_),&
                     !                         'recb=',Recb_I(i,j,k,globalBLK,mep_), Recb_I(i,j,k,globalBLK,hap_)
             end if
          end do
       end do
       !        end do
    end do ! Multi-block loop

!!!!!----------------- Interpolation/Expolation for ionization rates ---------------------
    !     open(1,file="ion_prod_rate.dat",status="old")
    !     read(1,*) (tmp_hR(i),tmp_RL0(i),tmp_RM0(i),tmp_RH0(i),i=1,num_Ri)
    !     close(1)
    RL0_BLK(:,:,:,globalBLK) = 0.00
    RM0_BLK(:,:,:,globalBLK) = 0.00
    RH0_BLK(:,:,:,globalBLK) = 0.00
    PhoIon_I(:,:,:,globalBLK,:) = 0.00

    do k=1,nK
       do j=1,nJ
          do i=1,nI
             if (R_BLK(i,j,k,globalBLK) >= Rbody) then
                hh = (R_BLK(i,j,k,globalBLK)-1.00)*2575.0
                n= int((hh -725.0)/10.0+1.0)
                if(n<1) then 
                   n=1
                else if(n> num_Ri-1) then
                   n = num_Ri-1
                end if

                dhn = hh - tmp_hR(n)
                dhnp1 = tmp_hR(n+1) - hh

                !                 write(*,*)'hh=', hh, 'n=', n
                !                cos_ISZA=cos(SZATitan*cPi/180.0)
                cosS0=(x_BLK(i,j,k,globalBLK)*SX0+y_BLK(i,j,k,globalBLK)*SY0)&
                     /max(R_BLK(i,j,k,globalBLK),1.0e-3)
                !                 if (cosS0 < cos_ISZA(9)) cosS0 = cos_ISZA(9)
                if (cosS0 < cos_ISZA(maxSZAm)) then
                   m=maxSZAm
                   !                    dhn = hh - tmp_hR(n)
                   !                    dhnp1 = tmp_hR(n+1) - hh
                   dtm = cos_ISZA(m)- cosS0
                   dtmp1 = cosS0+1.001
                   RL0_BLK(i,j,k,globalBLK) = (tmp_RL0(m,n)*dhnp1*dtmp1 + tmp_RL0(m,n+1)*dhn*dtmp1)&
                        /(tmp_hR(n+1)-tmp_hR(n))/(cos_ISZA(m)+1.001)
                   RM0_BLK(i,j,k,globalBLK) = (tmp_RM0(m,n)*dhnp1*dtmp1 + tmp_RM0(m,n+1)*dhn*dtmp1)&
                        /(tmp_hR(n+1)-tmp_hR(n))/(cos_ISZA(m)+1.001)
                   RH0_BLK(i,j,k,globalBLK) = (tmp_RH0(m,n)*dhnp1*dtmp1 + tmp_RH0(m,n+1)*dhn*dtmp1)&
                        /(tmp_hR(n+1)-tmp_hR(n))/(cos_ISZA(m)+1.001)                    

                else if (cosS0 > cos_ISZA(1)) then                    
                   m=1
                   !                    dhn = hh - tmp_hR(n)
                   !                    dhnp1 = tmp_hR(n+1) - hh
                   dtm = cos_ISZA(m)- cosS0
                   dtmp1 = cosS0 - cos_ISZA(m+1)
                   RL0_BLK(i,j,k,globalBLK) = (tmp_RL0(m,n)*dhnp1*dtmp1 + tmp_RL0(m,n+1)*dhn*dtmp1 +&
                        tmp_RL0(m+1,n)*dhnp1*dtm+tmp_RL0(m+1,n+1)*dhn*dtm)&
                        /(tmp_hR(n+1)-tmp_hR(n))/(cos_ISZA(m)-cos_ISZA(m+1))
                   RM0_BLK(i,j,k,globalBLK) = (tmp_RM0(m,n)*dhnp1*dtmp1 + tmp_RM0(m,n+1)*dhn*dtmp1 +&
                        tmp_RM0(m+1,n)*dhnp1*dtm+tmp_RM0(m+1,n+1)*dhn*dtm)&
                        /(tmp_hR(n+1)-tmp_hR(n))/(cos_ISZA(m)-cos_ISZA(m+1))
                   RH0_BLK(i,j,k,globalBLK) = (tmp_RH0(m,n)*dhnp1*dtmp1 + tmp_RH0(m,n+1)*dhn*dtmp1 +&
                        tmp_RH0(m+1,n)*dhnp1*dtm+tmp_RH0(m+1,n+1)*dhn*dtm)&
                        /(tmp_hR(n+1)-tmp_hR(n))/(cos_ISZA(m)-cos_ISZA(m+1))

                else                    
                   do m=1,maxSZAm-1
                      if((cosS0 <= cos_ISZA(m)).and.(cosS0 > cos_ISZA(m+1))) then
                         !                          dhn = hh - tmp_hR(n)
                         !                          dhnp1 = tmp_hR(n+1) - hh
                         dtm = cos_ISZA(m)- cosS0
                         dtmp1 = cosS0 - cos_ISZA(m+1)
                         RL0_BLK(i,j,k,globalBLK) = (tmp_RL0(m,n)*dhnp1*dtmp1 + tmp_RL0(m,n+1)*dhn*dtmp1 +&
                              tmp_RL0(m+1,n)*dhnp1*dtm+tmp_RL0(m+1,n+1)*dhn*dtm)&
                              /(tmp_hR(n+1)-tmp_hR(n))/(cos_ISZA(m)-cos_ISZA(m+1))
                         RM0_BLK(i,j,k,globalBLK) = (tmp_RM0(m,n)*dhnp1*dtmp1 + tmp_RM0(m,n+1)*dhn*dtmp1 +&
                              tmp_RM0(m+1,n)*dhnp1*dtm+tmp_RM0(m+1,n+1)*dhn*dtm)&
                              /(tmp_hR(n+1)-tmp_hR(n))/(cos_ISZA(m)-cos_ISZA(m+1))
                         RH0_BLK(i,j,k,globalBLK) = (tmp_RH0(m,n)*dhnp1*dtmp1 + tmp_RH0(m,n+1)*dhn*dtmp1 +&
                              tmp_RH0(m+1,n)*dhnp1*dtm+tmp_RH0(m+1,n+1)*dhn*dtm)&
                              /(tmp_hR(n+1)-tmp_hR(n))/(cos_ISZA(m)-cos_ISZA(m+1))

                      end if
                   end do
                end if


                RL0_BLK(i,j,k,globalBLK)=RL0_BLK(i,j,k,globalBLK)+ &
                     (IMPACT_L(n)*dhnp1+IMPACT_L(n+1)*dhn)/(tmp_hR(n+1)-tmp_hR(n))
                RM0_BLK(i,j,k,globalBLK)=RM0_BLK(i,j,k,globalBLK)+ &
                     (IMPACT_M(n)*dhnp1+IMPACT_M(n+1)*dhn)/(tmp_hR(n+1)-tmp_hR(n))
                RH0_BLK(i,j,k,globalBLK)=RH0_BLK(i,j,k,globalBLK)+ &
                     (IMPACT_H(n)*dhnp1+IMPACT_H(n+1)*dhn)/(tmp_hR(n+1)-tmp_hR(n))

                if (RL0_BLK(i,j,k,globalBLK) < 0.00) RL0_BLK(i,j,k,globalBLK) = 0.00
                if (RM0_BLK(i,j,k,globalBLK) < 0.00) RM0_BLK(i,j,k,globalBLK) = 0.00
                if (RH0_BLK(i,j,k,globalBLK) < 0.00) RH0_BLK(i,j,k,globalBLK) = 0.00

                PhoIon_I(i,j,k,globalBLK,Lp_) = &
                     RL0_BLK(i,j,k,globalBLK)&
                     *unitUSER_t/unitUSER_n
                PhoIon_I(i,j,k,globalBLK,Mp_) = &
                     RM0_BLK(i,j,k,globalBLK)&
                     *unitUSER_t/unitUSER_n
                PhoIon_I(i,j,k,globalBLK,H1p_) = &
                     RH0_BLK(i,j,k,globalBLK)&
                     *unitUSER_t/unitUSER_n
                !                 if(hh.lt.1500.0.and.cosS0.gt.0.998)then
                !                    write(*,*)hh, RH0_BLK(i,j,k,globalBLK), cosS0
                !                 end if
             end if
          end do
       end do

    end do ! Multi-block loop

!!!!!----------------- Interpolation/Expolation for neutral densities ---------------------
    !  open(1,file="n.dat",status="old")
    !    read(1,*) (tmp_rn(i),tmp_nL(i),tmp_nM(i),tmp_nH(i),i=1,num_n)
    !  close(1)
    !nL_BLK(:,:,:,globalBLK) = 0.00
    !nM_BLK(:,:,:,globalBLK) = 0.00
    !nH_BLK(:,:,:,globalBLK) = 0.00

    !  tmp_n(15,:)=tmp_n(C4H2_,:)  !5
    !  tmp_n(HC3N_,:)=tmp_n(11,:) !10
    !  tmp_n(C3H4_,:)= tmp_n(12,:) !4
    !  tmp_n(C4H2_,:)=tmp_n(15,:)  !5

    nu_BLK(:,:,:,globalBLK) = 0.00
    nDenNuSpecies_CBI(:,:,:,globalBLK,:)=0.00
    !  tmp_hn = tmp_rn-2575.0
    !  do globalBLK = 1,nBlockMax
    do k=1,nK
       do j=1,nJ
          do i=1,nI
             if (R_BLK(i,j,k,globalBLK) >= Rbody) then
                hh = (R_BLK(i,j,k,globalBLK)-1.00)*2575.0
                n= int((hh -725.0)/10.0+1.0)
!!!!!------------ Interpolation/Expolation for nL_BLK, nM_BLK, nH_BLK--------------
                if (hh < tmp_hn(1)) then
                   nDenNuSpecies_CBI(i,j,k,globalBLK,:) = tmp_n(1:nNuSpecies,1) + &
                        (tmp_n(1:nNuSpecies,1)-tmp_n(1:nNuSpecies,2))*(tmp_hn(1)-hh)/(tmp_hn(2)-tmp_hn(1))
                else if(hh > tmp_hn(num_nu-1)) then
                   nDenNuSpecies_CBI(i,j,k,globalBLK,:) = tmp_n(1:nNuSpecies,num_nu) + &
                        (tmp_n(1:nNuSpecies,num_nu)-tmp_n(1:nNuSpecies,num_nu-1))*&
                        (hh-tmp_hn(num_nu))/(tmp_hn(num_nu)-tmp_hn(num_nu-1))
                else                                  
                   nDenNuSpecies_CBI(i,j,k,globalBLK,:) = tmp_n(1:nNuSpecies,n) + &
                        (tmp_n(1:nNuSpecies,n+1)-tmp_n(1:nNuSpecies,n))*(hh-tmp_hn(n))/(tmp_hn(n+1)-tmp_hn(n))
                end if
                
                nDenNuSpecies_CBI(i,j,k,globalBLK,:)=max(0.00, nDenNuSpecies_CBI(i,j,k,globalBLK,:))

                nDenNuSpecies_CBI(i,j,k,globalBLK,:) = &
                     nDenNuSpecies_CBI(i,j,k,globalBLK,:)/unitUSER_n
                nu_BLK(i,j,k,globalBLK) = nu0*sum(nDenNuSpecies_CBI(i,j,k,globalBLK,1:nNuSpecies))              
             end if
          end do
       end do
       !  end do
    end do ! Multi-block loop

    ! if(globalBLK.gt.43.and.globalBLK.lt.50) write(*,*)'globalBLK=',globalBLK,&
    !      'R,nu=',R_BLK(3,1,4,globalBLK),nu_BLK(3,1,4,globalBLK)
  end subroutine Titan_Input

  !====================================================================

  subroutine user_set_plot_var(iBlock, NameVar, IsDimensional, &
       PlotVar_G, PlotVarBody, UsePlotVarBody, &
       NameTecVar, NameTecUnit, NameIdlUnit, IsFound)

    use ModPhysics, ONLY: rBody, unituser_B
    use ModMain, ONLY: Body1_
    use ModAdvance, ONLY: State_VGB, Bx_, By_, Bz_, B_
    use ModGeometry, ONLY: x_BLK, y_BLK, z_BLK, r_BLK, IsBoundaryBlock_IB

    use ModSize, ONLY: nI, nJ, nK
    use ModMain, ONLY: iTest, jTest, kTest, ProcTest, BlkTest, &
         GLOBALBLK
    use ModProcMH,   ONLY: iProc


    integer,          intent(in) :: iBlock
    character(len=*), intent(in) :: NameVar
    logical,          intent(in) :: IsDimensional
    real,             intent(out):: PlotVar_G(-1:nI+2, -1:nJ+2, -1:nK+2)
    real,             intent(out):: PlotVarBody
    logical,          intent(out):: UsePlotVarBody
    character(len=*), intent(out):: NameTecVar
    character(len=*), intent(out):: NameTecUnit
    character(len=*), intent(out):: NameIdlUnit
    logical,          intent(out):: IsFound

    character (len=*), parameter :: Name='user_set_plot_var'

    integer :: iVar, i, j, k
    real :: Xyz_D(3), NormXyz_D(3),r, Br0, Br1, Br2, B_D(3), dBr_D(3)

    logical :: oktest,oktest_me
    !------------------------------------------------------------------------  
    if(iProc==PROCtest .and. iBlock==BLKtest)then
       call set_oktest('user_set_plot_var',oktest,oktest_me)
    else
       oktest=.false.; oktest_me=.false.
    end if

    select case(NameVar)
    case('b_x_r')
       iVar=Bx_
       NameTecVar = 'b_x_r'
    case('b_y_r')
       iVar=By_
       NameTecVar = 'b_y_r'
    case('b_z_r')
       iVar=Bz_
       NameTecVar = 'b_z_r'
    case default
       call stop_mpi(Name//': unimplemented variable='//NameVar)
    end select
    NameTecUnit = '[nT]'
    NameIdlUnit = 'nT'
    PlotVar_G = State_VGB(iVar,:,:,:,iBlock)
    UsePlotVarBody = .true.
    PlotVarBody    = 0.0

    if(IsDimensional) PlotVar_G = PlotVar_G*UnitUser_B

    if(.not.IsBoundaryBlock_IB(body1_, iBlock)) RETURN

    ! Reflect at surface of the body
    do i=0,nI
       if(r_BLK(i+1,1,1,iBlock)>=rBody) EXIT
    end do

    if(oktest_me)&
         write(*,*)'i,r_BLK(i,1,1,iBlock),rBody=',i,r_BLK(i,1,1,iBlock),rBody

    if(r_BLK(i,1,1,iBlock)>rBody) RETURN

    i=i+1
    do k=-1,nK+2; do j=-1,nJ+2
       Xyz_D = &
            (/ x_BLK(i,j,k,iBlock), y_BLK(i,j,k,iBlock), z_BLK(i,j,k,iBlock)/)
       r= r_BLK(i,j,k,iBlock)
       NormXyz_D = Xyz_D/r

       B_D = State_VGB(Bx_:Bz_,i,j,k,iBlock)
       Br0 = sum(NormXyz_D*B_D)

       Br1 = sum(NormXyz_D*State_VGB(Bx_:Bz_,i+1,j,k,iBlock))
       Br2 = sum(NormXyz_D*State_VGB(Bx_:Bz_,i+2,j,k,iBlock))
          
       ! Change radial component so that field is reflected at i+1/2
       dBr_D = (-Br2 - 2*Br1 - Br0)*NormXyz_D
       
       ! Apply change
       B_D = B_D + dBr_D
       
       PlotVar_G(i,j,k) = B_D(iVar-B_)

       if(oktest_me.and.j==jTest.and.k==kTest)then
          write(*,*)'i=',i,'iTest=',iTest
          write(*,*)'r=',r,&
               'r_BLK(iTest,j,k,iBlock)=',r_BLK(iTest,j,k,iBlock)
          write(*,*)'Br0, Br1,Br2=',Br0, Br1,Br2
          write(*,*)'State_VGB(Bx_:Bz_,i,j,k,iBlock)=',&
               State_VGB(Bx_:Bz_,i,j,k,iBlock)
          write(*,*)'B_D=', B_D
          write(*,*)'NormXyz_D=',NormXyz_D
       end if
          

    end do; end do

  end subroutine user_set_plot_var


end Module ModUser
