!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf

module IH_wrapper

  ! Wrapper for IH_BATSRUS Inner Heliosphere (IH) component

  use IH_domain_decomposition, ONLY: IH_LineDD=>MH_LineDecomposition

  use IH_ModBuffer

  use IH_ModBatsrusMethods, ONLY: &
       BATS_init_session, BATS_setup, BATS_advance, BATS_save_files, &
       BATS_finalize

  implicit none

  private ! except

  ! CON wrapper
  public:: IH_set_param
  public:: IH_init_session
  public:: IH_run
  public:: IH_save_restart
  public:: IH_finalize

  ! Global buffer coupling
  public:: IH_get_for_global_buffer
  public:: IH_xyz_to_coord, IH_coord_to_xyz

  ! spherical buffer coupling from IH_ModBuffer (why?)
  public:: nVarCouple, iVar_V, DoCoupleVar_V

  ! Coupling toolkit
  public:: IH_synchronize_refinement
  public:: IH_get_for_mh
  public:: IH_put_from_mh
  public:: IH_n_particle
  public:: IH_LineDD

  ! Coupling with SC
  public:: IH_set_buffer_grid_get_info
  public:: IH_save_global_buffer
  public:: IH_match_ibc

  ! Point coupling
  public:: IH_get_grid_info
  public:: IH_find_points

  ! Coupling with SP
  public:: IH_check_ready_for_sp
  public:: IH_extract_line
  public:: IH_put_particles
  public:: IH_get_particle_indexes
  public:: IH_get_particle_coords
 
  ! Coupling with GM
  public:: IH_get_for_gm

  ! Coupling with PT
  public:: IH_get_for_pt
  public:: IH_put_from_pt
  public:: IH_get_for_pt_dt

  ! Coupling with EE (for SC)
  public:: IH_get_for_ee
  public:: IH_put_from_ee

contains
  !==========================================================================

  subroutine IH_init_session(iSession, TimeSimulation)

    !INPUT PARAMETERS:
    integer,  intent(in) :: iSession         ! session number (starting from 1)
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='IH_init_session'

    logical :: IsUninitialized = .true.
    logical :: DoTest, DoTestMe
    !--------------------------------------------------------------------------
    call CON_set_do_test(NameSub,DoTest, DoTestMe)

    if(IsUninitialized)then
       call BATS_setup
       IsUninitialized = .false.
    end if
    call BATS_init_session

    if(DoTest)write(*,*)NameSub,' finished for session ',iSession

  end subroutine IH_init_session

  !==========================================================================
  subroutine IH_set_param(CompInfo, TypeAction)

    use CON_comp_info
    use IH_BATL_lib, ONLY: iProc, nProc, iComm
    use IH_ModIO, ONLY: iUnitOut, StringPrefix, STDOUT_, NamePlotDir
    use IH_ModSetParameters, ONLY: set_parameters
    use IH_ModRestartFile, ONLY: NameRestartInDir, NameRestartOutDir
    use IH_ModMain, ONLY : CodeVersion, NameThisComp, &
         time_accurate, time_simulation, StartTime, iStartTime_I
    use CON_physics, ONLY: get_time
    use ModTimeConvert, ONLY: time_real_to_int

    character (len=*), parameter :: NameSub='IH_set_param'

    ! Arguments
    type(CompInfoType), intent(inout):: CompInfo   ! Information for this comp.
    character (len=*), intent(in)    :: TypeAction ! What to do

    logical :: DoTest,DoTestMe
    !-------------------------------------------------------------------------
    call CON_set_do_test(NameSub,DoTest,DoTestMe)

    if(DoTest)write(*,*)NameSub,' called with TypeAction,iProc=',&
         TypeAction,iProc

    select case(TypeAction)
    case('VERSION')
       call put(CompInfo,&
            Use        =.true.,                        &
            NameVersion='IH_BATSRUS (Univ. of Michigan)', &
            Version    =CodeVersion)
    case('MPI')
       call get(CompInfo, iComm=iComm, iProc=iProc, nProc=nProc,&
            Name=NameThisComp)

       NamePlotDir(1:2)      = NameThisComp
       NameRestartInDir(1:2) = NameThisComp
       NameRestartOutDir(1:2)= NameThisComp
    case('READ','CHECK')
       call get_time( &
            DoTimeAccurateOut = time_accurate, &
            tSimulationOut=Time_Simulation, &
            tStartOut         = StartTime)
       call time_real_to_int(StartTime,iStartTime_I)

       call set_parameters(TypeAction)
    case('STDOUT')
       iUnitOut=STDOUT_
       if(iProc==0)then
          StringPrefix = NameThisComp//':'
       else
          write(StringPrefix,'(a,i4.4,a)')NameThisComp,iProc,':'
       end if
    case('FILEOUT')
       call get(CompInfo,iUnitOut=iUnitOut)
       StringPrefix=''
    case('GRID')
       call IH_set_grid
    case default
       call CON_stop(NameSub//' SWMF_ERROR: invalid TypeAction='//TypeAction)
    end select
  end subroutine IH_set_param

  !============================================================================

  subroutine IH_finalize(TimeSimulation)

    use IH_ModMain, ONLY: time_loop

    !INPUT PARAMETERS:
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='IH_finalize'

    integer :: iError
    !--------------------------------------------------------------------------
    ! We are not advancing in time any longer
    time_loop = .false.

    call BATS_save_files('FINAL')

    call IH_error_report('PRINT',0.,iError,.true.)

  end subroutine IH_finalize

  !============================================================================

  subroutine IH_save_restart(TimeSimulation)

    !INPUT PARAMETERS:
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='IH_save_restart'

    call BATS_save_files('RESTART')

  end subroutine IH_save_restart

  !============================================================================

  subroutine IH_run(TimeSimulation,TimeSimulationLimit)

    use IH_BATL_lib, ONLY: iProc
    use IH_ModMain, ONLY: Time_Simulation

    !INPUT/OUTPUT ARGUMENTS:
    real, intent(inout):: TimeSimulation   ! current time of component

    !INPUT ARGUMENTS:
    real, intent(in):: TimeSimulationLimit ! simulation time not to be exceeded

    character(len=*), parameter :: NameSub='IH_run'

    logical :: DoTest, DoTestMe
    !--------------------------------------------------------------------------
    call CON_set_do_test(NameSub,DoTest,DoTestMe)

    if(DoTest)write(*,*)NameSub,' called with tSim, tSimLimit, iProc=',&
         TimeSimulation, TimeSimulationLimit, iProc

    if(abs(Time_Simulation-TimeSimulation)>0.0001) then
       write(*,*)NameSub, &
            ' IH time=',Time_Simulation,' SWMF time=',TimeSimulation
       call CON_stop(NameSub//': IH and SWMF simulation times differ')
    end if

    call BATS_advance(TimeSimulationLimit)

    ! Return time after the time step
    TimeSimulation = Time_Simulation

  end subroutine IH_run

  !============================================================================
  subroutine IH_get_grid_info(nDimOut, iGridOut, iDecompOut)

    use IH_BATL_lib, ONLY: nDim
    use IH_ModMain,  ONLY: iNewGrid, iNewDecomposition

    integer, intent(out):: nDimOut    ! grid dimensionality
    integer, intent(out):: iGridOut   ! grid index (increases with AMR)
    integer, intent(out):: iDecompOut ! decomposition index 

    character(len=*), parameter :: NameSub='IH_get_grid_info'

    ! Return basic grid information useful for model coupling.
    ! The decomposition index increases with load balance and AMR.
    !--------------------------------------------------------------------------

    nDimOut    = nDim
    iGridOut   = iNewGrid
    iDecompOut = iNewDecomposition

  end subroutine IH_get_grid_info
  !============================================================================
  subroutine IH_find_points(nDimIn, nPoint, Xyz_DI, iProc_I)

    use IH_BATL_lib,   ONLY: MaxDim, find_grid_block
    use IH_ModPhysics, ONLY: Si2No_V, UnitX_

    integer, intent(in) :: nDimIn                ! dimension of positions
    integer, intent(in) :: nPoint                ! number of positions
    real,    intent(in) :: Xyz_DI(nDimIn,nPoint) ! positions
    integer, intent(out):: iProc_I(nPoint)       ! processor owning position

    ! Find array of points and return processor indexes owning them
    ! Could be generalized to return multiple processors...

    real:: Xyz_D(MaxDim) = 0.0
    integer:: iPoint, iBlock

    character(len=*), parameter:: NameSub = 'IH_find_points'
    !--------------------------------------------------------------------------
    do iPoint = 1, nPoint
       Xyz_D(1:nDimIn) = Xyz_DI(:,iPoint)*Si2No_V(UnitX_)
       call find_grid_block(Xyz_D, iProc_I(iPoint), iBlock)
    end do

  end subroutine IH_find_points

  !===========================================================================
  subroutine IH_get_point_data( &
       iBlockCell_DI, Dist_DI, IsNew, &
       NameVar, nVarIn, nDimIn, nPoint, Xyz_DI, Data_VI, &
       DoSendAllVar)
    
    ! Generic routine for providing point data to another component
    ! If DoSendAllVar is true, send all variables in State_VGB
    ! Otherwise send the variables defined by iVarSource_V

    use IH_ModPhysics, ONLY: Si2No_V, UnitX_, No2Si_V, iUnitCons_V
    use IH_ModAdvance, ONLY: State_VGB, Bx_, Bz_
    use IH_ModVarIndexes, ONLY: nVar
    use IH_ModB0,      ONLY: UseB0, get_b0
    use IH_BATL_lib,   ONLY: nDim, MaxDim, MinIJK_D, MaxIJK_D, iProc, &
         find_grid_block
    use IH_ModIO, ONLY: iUnitOut
    use CON_coupler,    ONLY: iVarSource_V
    use ModInterpolate, ONLY: interpolate_vector

    logical,          intent(in):: IsNew   ! true for new point array
    integer, allocatable, intent(inout):: iBlockCell_DI(:,:) ! interp. index
    real,    allocatable, intent(inout):: Dist_DI(:,:)       ! interp. weight

    character(len=*), intent(in):: NameVar ! List of variables
    integer,          intent(in):: nVarIn  ! Number of variables in Data_VI
    integer,          intent(in):: nDimIn  ! Dimensionality of positions
    integer,          intent(in):: nPoint  ! Number of points in Xyz_DI

    real, intent(in) :: Xyz_DI(nDimIn,nPoint)  ! Position vectors
    real, intent(out):: Data_VI(nVarIn,nPoint) ! Data array

    logical, intent(in), optional:: DoSendAllVar

    logical:: DoSendAll

    real:: Xyz_D(MaxDim), B0_D(MaxDim)
    real:: Dist_D(MaxDim), State_V(nVar)
    integer:: iCell_D(MaxDim)

    integer:: iPoint, iBlock, iProcFound, iVarBuffer, iVar

    logical:: DoTest, DoTestMe
    character(len=*), parameter:: NameSub='IH_get_point_data'
    !--------------------------------------------------------------------------
    call CON_set_do_test(NameSub, DoTest, DoTestMe)

    DoSendAll = .false.
    if(present(DoSendAllVar)) DoSendAll = DoSendAllVar

    ! If nDim < MaxDim, make sure that all elements are initialized
    Dist_D = -1.0
    Xyz_D  =  0.0

    if(IsNew)then
       ! Find points and store cell indexes and weights

       if(DoTest)write(iUnitOut,*) NameSub,': iProc, nPoint=', iProc, nPoint

       if(allocated(iBlockCell_DI)) deallocate(iBlockCell_DI, Dist_DI)
       allocate(iBlockCell_DI(0:nDim,nPoint), Dist_DI(nDim,nPoint))

       do iPoint = 1, nPoint

          Xyz_D(1:nDim) = Xyz_DI(:,iPoint)*Si2No_V(UnitX_)
          call find_grid_block(Xyz_D, iProcFound, iBlock, iCell_D, Dist_D, &
               UseGhostCell = .true.)

          if(iProcFound /= iProc)then
             write(*,*) NameSub,' ERROR: Xyz_D, iProcFound=', Xyz_D, iProcFound
             call IH_stop_mpi(NameSub//' could not find position on this proc')
          end if

          ! Store block and cell indexes and distances for interpolation
          iBlockCell_DI(0,iPoint)      = iBlock
          iBlockCell_DI(1:nDim,iPoint) = iCell_D(1:nDim)
          Dist_DI(:,iPoint)            = Dist_D(1:nDim)

       end do
    end if

    ! Interpolate coupled variables to the point positions
    do iPoint = 1, nPoint
       Xyz_D(1:nDim) = Xyz_DI(:,iPoint)*Si2No_V(UnitX_)

       ! Use stored block and cell indexes and distances
       iBlock          = iBlockCell_DI(0,iPoint)
       iCell_D(1:nDim) = iBlockCell_DI(1:nDim,iPoint)
       Dist_D(1:nDim)  = Dist_DI(:,iPoint)

       ! Interpolate
       State_V = interpolate_vector(State_VGB(:,:,:,:,iBlock), nVar, nDim, &
            MinIJK_D, MaxIJK_D, iCell_D=iCell_D, Dist_D=Dist_D)

       ! Provide full B
       if(UseB0)then
          call get_b0(Xyz_D, B0_D)
          State_V(Bx_:Bz_) = State_V(Bx_:Bz_) + B0_D
       end if

       ! Fill buffer with interpolated values converted to SI units
       if(DoSendAll)then
          Data_VI(:,iPoint) = State_V*No2Si_V(iUnitCons_V)
       else
          do iVarBuffer = 1, nVarIn
             iVar = iVarSource_V(iVarBuffer)
             Data_VI(iVarBuffer,iPoint) = &
                  State_V(iVar)*No2Si_V(iUnitCons_V(iVar))
          end do
       end if
    end do

  end subroutine IH_get_point_data
  !============================================================================
  subroutine IH_set_grid

    use CON_comp_param
    use IH_domain_decomposition
    use CON_coupler
    use IH_ModMain, ONLY: TypeCoordSystem, nVar, NameVarCouple
    use IH_ModPhysics,ONLY:No2Si_V, UnitX_
    use IH_ModGeometry,   ONLY: RadiusMin, RadiusMax
    use IH_BATL_geometry, ONLY: TypeGeometry, IsGenRadius, LogRGen_I 
    use IH_BATL_lib, ONLY: CoordMin_D, CoordMax_D, Particle_I
    use IH_ModParticleFieldLine, ONLY: KindReg_, &
         UseParticles
    logical:: DoTest,DoTestMe
    logical:: UseParticleLine = .false.
    integer:: nParticle = 0, iError = 0
    character(len=*), parameter:: NameSub = 'IH_set_grid'
    !--------------------------------------------------------------------------

    DoTest=.false.;DoTestMe=.false.
    ! Here we should set the IH (MH) grid descriptor
    if(done_dd_init(IH_))return
    call init_decomposition(&
         GridID_=IH_,&
         CompID_=IH_,&
         nDim=3,     &
         IsTreeDecomposition=.true.)

    if(IsGenRadius)then
       call set_coord_system(            &
            GridID_   = IH_,             &
            TypeCoord = TypeCoordSystem, &
            UnitX     = No2Si_V(UnitX_), &
            nVar      = nVar,            &
            NameVar   = NameVarCouple,   &
            TypeGeometry = TypeGeometry, &
            Coord1_I  = LogRGen_I,       &
            Coord2_I  = (/RadiusMin, RadiusMax/))
    else
       call set_coord_system(&
            GridID_   = IH_,             &
            TypeCoord = TypeCoordSystem, &
            UnitX     = No2Si_V(UnitX_), &
            nVar      = nVar,            &
            NameVar   = NameVarCouple,   &
            TypeGeometry = TypeGeometry, &
            Coord2_I  = (/RadiusMin, RadiusMax/))
    end if

    if(is_Proc(IH_))then
       !Initialize the local grid

       call init_decomposition(&
            Domain=MH_Domain,&
            CompID_=IH_,&
            nDim=3,&
            IsTreeDecomposition=.true.)

       !Get the octree root array
       call MH_get_root_decomposition(MH_Domain)

       !Get the whole octree after the initial refinement
       call MH_update_local_decomposition(MH_Domain)

       MH_Domain%IsLocal=.true.
    end if
    call CON_set_do_test('test_grids',DoTest,DoTestMe)
    !Repeat the initialization at the global grid level:
    !Octree root array:
    if(is_proc0(IH_))call MH_get_root_decomposition(IH_)

    !Broadcast root array:
    call bcast_decomposition(IH_)

    !Synchronize global and local grids:
    call synchronize_refinement(&
         GridID_=IH_,&
         LocalDomain=MH_Domain)
    if(is_proc0(IH_))UseParticleLine = UseParticles
    call MPI_bcast(UseParticleLine,1,MPI_LOGICAL,&
         i_proc0(IH_),i_comm(),iError)
    if(UseParticleLine)then
       call init_decomposition_dd(&
       MH_LineDecomposition, IH_, nDim=1)
       if(is_proc0(IH_))then
          nParticle = Particle_I(KindReg_)%nParticleMax
          call get_root_decomposition_dd(&
               MH_LineDecomposition, &
               (/n_proc(IH_)/),      &
               (/0.50/),              &
               ! factors are converted separately to prevent
               ! integer overflow
               (/real(n_proc(IH_))*real(nParticle) + 0.50/), &
               (/nParticle/))
       end if
       call bcast_decomposition_dd(MH_LineDecomposition)
       if(DoTest.and.is_proc0(IH_))call show_domain_decomp(&
            MH_LineDecomposition)
    end if
  end subroutine IH_set_grid
  !============================
  subroutine IH_xyz_to_coord(XyzIn_D, CoordOut_D)
    use CON_coupler
    use ModCoordTransform, ONLY: &
         atan2_check, xyz_to_sph, xyz_to_rlonlat
    real,             intent(in ) :: XyzIn_D(3)
    real,             intent(out) :: CoordOut_D(3)

    real               :: x, y
    integer, parameter :: x_=1, y_=2, z_=3, r_=1
    integer            :: Phi_
    character(len=20)  :: TypeGeometry
    character(len=*), parameter :: NameSub = 'IH_xyz_to_coord'
    !----------------------------------------
    TypeGeometry = Grid_C(IH_)%TypeGeometry
    if(TypeGeometry(1:9)  == 'cartesian')then
       CoordOut_D = XyzIn_D
       RETURN
    elseif(TypeGeometry(1:3)  == 'cyl')then
       Phi_ = 2
       x = XyzIn_D(x_); y = XyzIn_D(y_)
       CoordOut_D(r_)   = sqrt(x**2 + y**2)
       CoordOut_D(Phi_) = atan2_check(y, x)
       CoordOut_D(z_)   = XyzIn_D(z_)
    elseif(TypeGeometry(1:3)  == 'sph')then
       call xyz_to_sph(XyzIn_D, CoordOut_D)
    elseif(TypeGeometry(1:3)  == 'rlo')then
       call xyz_to_rlonlat(XyzIn_D, CoordOut_D)
    else
       call CON_stop(NameSub// &
            ' not yet implemented for TypeGeometry='//TypeGeometry)
    end if
    if(index(TypeGeometry,'lnr')  > 0)then
       CoordOut_D(1) = log(max(CoordOut_D(1), 1e-30))
    elseif(index(TypeGeometry,'genr') > 0)then
       call radius_to_gen(CoordOut_D(1))
    end if
  contains
    subroutine radius_to_gen(r)
      use ModInterpolate, ONLY: find_cell
      real, intent(inout) :: r

      integer       :: nRgen
      integer       :: i
      real          :: dCoord
      real, pointer :: LogRgen_I(:)
      !-------------
      LogRgen_I=>Grid_C(IH_)%Coord1_I
      nRgen    = Grid_C(IH_)%nCoord_D(1)
      call find_cell(0, nRgen-1, alog(r), &
           i, dCoord, LogRgen_I, DoExtrapolate=.true.)
      r = (i + dCoord)/(nRgen - 1)
    end subroutine radius_to_gen
  end subroutine IH_xyz_to_coord
  !=============================
  subroutine IH_coord_to_xyz(CoordIn_D, XyzOut_D)
    use CON_coupler
    use ModCoordTransform, ONLY: sph_to_xyz, rlonlat_to_xyz
    real, intent(in) :: CoordIn_D(3)
    real, intent(out):: XyzOut_D( 3)

    real               :: Coord_D(3), r, Phi
    integer, parameter :: x_=1, r_=1
    integer            :: Phi_
    character(len=20)  :: TypeGeometry
    character(len=*), parameter :: NameSub = 'IH_coord_to_xyz'
    !-------------------------------------------------------------
    TypeGeometry = Grid_C(IH_)%TypeGeometry
    if(TypeGeometry(1:9)  == 'cartesian')then
       XyzOut_D = CoordIn_D
       RETURN
    endif

    Coord_D = CoordIn_D
    if(index(TypeGeometry,'lnr')  > 0)then
       Coord_D(1) = exp(Coord_D(1))
    elseif(index(TypeGeometry,'genr') > 0)then
       call gen_to_radius(Coord_D(1))
    end if

    if(TypeGeometry(1:3)  == 'cyl')then
       Phi_ = 2
       r = Coord_D(r_); Phi = Coord_D(Phi_)
       XyzOut_D(1) = r*cos(Phi)
       XyzOut_D(2) = r*sin(Phi)
       XyzOut_D(3) = Coord_D(3)
    elseif(TypeGeometry(1:3)  == 'sph')then
       call sph_to_xyz(Coord_D, XyzOut_D)
    elseif(TypeGeometry(1:3)  == 'rlo')then
       call rlonlat_to_xyz(Coord_D, XyzOut_D)
    else
       call CON_stop(NameSub// &
            ' not yet implemented for TypeGeometry='//TypeGeometry)
    end if
  contains
    subroutine gen_to_radius(r)
      use ModInterpolate, ONLY: linear
      
      ! Convert generalized radial coordinate to true radial coordinate
      real, intent(inout):: r
      integer       :: nRgen
      real, pointer :: LogRgen_I(:)
      !-------------
      LogRgen_I=>Grid_C(IH_)%Coord1_I
      nRgen    = Grid_C(IH_)%nCoord_D(1)
      
      ! interpolate the LogRgen_I array for the general coordinate
      r = exp(linear(LogRgen_I, 0, nRgen-1, r*(nRgen-1), DoExtrapolate=.true.))
    end subroutine gen_to_radius
  end subroutine IH_coord_to_xyz

  !===============================================================

  subroutine IH_synchronize_refinement(iProc0,iCommUnion)

    use IH_domain_decomposition
    use CON_comp_param

    integer, intent(in) ::iProc0,iCommUnion

    !Synchronize the local grid decomposition to accomodate the
    !grid change.

    if(is_proc(IH_)) &
         call MH_update_local_decomposition(MH_Domain)

    call synchronize_refinement(&
         GridID_=IH_,&
         LocalDomain=MH_Domain,&
         iProcUnion=iProc0,&
         iCommUnion=iCommUnion)

  end subroutine IH_synchronize_refinement

  !============================================================================

  subroutine IH_set_buffer_grid_get_info(CompID_, &
       nR, nPhi, nTheta, BufferMinMax_DI)

    use IH_domain_decomposition, ONLY: is_proc
    use IH_ModMain,              ONLY: BuffR_, nPhiBuff, nThetaBuff,&
         nRBuff, BufferMin_D, BufferMax_D, dSphBuff_D

    integer, intent(in)     :: CompID_
    integer, intent(out)    :: nR, nPhi, nTheta
    real, intent(out)       :: BufferMinMax_DI(3,2)

    integer  :: nCell_D(3)
    logical :: DoTest, DoTestMe

    character(len=*), parameter :: NameSub = 'IH_set_buffer_grid_get_info'
    !--------------------------------------------------------------------------
    call CON_set_do_test(NameSub,DoTest, DoTestMe)

    ! Make sure only a coupling target component is executing this 
    if(.not. is_proc(CompID_)) RETURN

    ! Return buffer size and limits to SWMF calling routine
    BufferMinMax_DI(:,1) = BufferMin_D
    BufferMinMax_DI(:,2) = BufferMax_D

    nR     = nRBuff 
    nPhi   = nPhiBuff
    nTheta = nThetaBuff

    ! Calculate grid spacing and save in IH_BATSRUS
    nCell_D = (/nR, nPhi, nTheta/)
    dSphBuff_D = (BufferMax_D - BufferMin_D)/real(nCell_D)
    dSphBuff_D(BuffR_) = (BufferMax_D(BuffR_) - BufferMin_D(BuffR_)) &
         /real(nCell_D(BuffR_) - 1)

    if(DoTest) then
       write(*,*) NameSub,': with nR, nPhi, nTheta = ',nCell_D
       write(*,*) 'BufferMin_D: ',BufferMin_D
       write(*,*) 'BufferMax_D: ',BufferMax_D
       write(*,*) 'dSph_D: ',dSphBuff_D
    end if

  end subroutine IH_set_buffer_grid_get_info

  !============================================================================

  subroutine IH_save_global_buffer(nVar, nR, nPhi, nTheta,BufferIn_VG)

    use IH_ModMain, ONLY: BufferState_VG
    use IH_ModMessagePass, ONLY: DoExtraMessagePass

    integer,intent(in) :: nVar, nR, nPhi, nTheta
    real,intent(in)    :: BufferIn_VG(nVar,nR,0:nPhi+1,0:nTheta+1)

    character(len=*), parameter :: NameSub = 'IH_save_global_buffer'
    !-------------------------------------------------------------
    if(.not. allocated(BufferState_VG))&
         allocate(BufferState_VG(nVar, nR, 0:nPhi+1, 0:nTheta+1))
    BufferState_VG = BufferIn_VG

    ! Make sure that ghost cells get filled after 
    DoExtraMessagePass = .true.

  end subroutine IH_save_global_buffer

  !===========================================================================
  subroutine IH_match_ibc

    use IH_ModMessagePass, ONLY: exchange_messages, fill_in_from_buffer
    use IH_ModGeometry,ONLY:R_BLK
    use IH_BATL_lib,  ONLY: Xyz_DGB, iProc
    use IH_ModMain,   ONLY:&
         nI,nJ,nK, BufferMax_D, MaxDim,nBlock, Unused_B
    use IH_ModAdvance,ONLY:nVar,State_VGB,rho_,rhoUx_,rhoUz_,Ux_,Uz_
    use IH_ModIO,     ONLY:IsRestartCoupler

    character(len=*), parameter :: NameSub='IH_match_ibc'
    character(len=*), parameter :: StringTest ='IH_fill_buffer_only'

    integer  :: iBlock
    integer  :: i,j,k
    real     :: x_D(MaxDim), rBuffMax
    logical  :: DoTest,DoTestMe
    ! ------------------------------------------------------------------------
    if(IsRestartCoupler) RETURN

    rBuffMax = BufferMax_D(1)

    call CON_set_do_test(StringTest, DoTest, DoTestMe)
    if(DoTest .and. iProc == 0)  write(*,*) &
         NameSub,' in test mode: no filling of cells outside the buffer grid.'

    ! Fill all spatial domain with values depend on the BC
    do iBlock = 1, nBlock
       if(Unused_B(iBlock))CYCLE

       ! Fill in the cells, covered by the bufer grid, including ghost cells
       call fill_in_from_buffer(iBlock)

       ! Fill in the physical cells, which are outside the buffer grid
       ! When testing, do not fill cells outside the buffer
       if(.not. DoTest) then 
          do k = 1, nK; do j = 1 , nJ; do i = 1, nI
             if(R_BLK(i,j,k,iBlock) < rBuffMax)CYCLE

             ! For each grid point, get the values at the base (buffer) 
             x_D = Xyz_DGB(:,i,j,k,iBlock)*rBuffMax/R_BLK(i,j,k,iBlock)

             ! The grid point values are extracted from the base values
             call IH_get_from_spher_buffer_grid(&
                  x_D, nVar, State_VGB(:,i,j,k,iBlock))

             !Transform primitive variables to conservative ones:
             State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock)=&
                  State_VGB(Ux_:Uz_,i,j,k,iBlock)*&
                  State_VGB(rho_,i,j,k,iBlock)

             !Scale as (r/R)^2:
             State_VGB(:,i,j,k,iBlock)=&
                  State_VGB(:,i,j,k,iBlock)*&
                  (rBuffMax/R_BLK(i,j,k,iBlock))**2

          end do; end do; end do
       end if
    end do

    ! Fill in the ghostcells, calculate energy
    call exchange_messages 

  end subroutine IH_match_ibc

  !============================================================================

  subroutine IH_get_for_global_buffer(&
       nR, nPhi,nTheta, BufferMinMax_DI, &
       TimeCoupling, iCompSource, iCompTarget, Buffer_VG)

    ! DESCRIPTION

    ! This subroutines fills a buffer grid by interpolating from a source 
    ! IH_BATSRUS grid using second-order trilinear interpolation.

    ! The buffer grid can be a spherical shell, or a segment of such a shell.

    ! All state variables in the source grid are interpolated, but only those
    ! needed for coupling (as determined by CON_coupler) are actually passed. 

    ! The filled buffer state vector is converted to SI units and vector 
    ! quantities are rotated to the target component coordinate system.

    ! INPUT:

    ! nR, nPhi, nTheta: grid spacing for the buffer grid
    ! BufferMinMAx_DI : Buffer grid minimum and maximum coordinates, in all
    ! dimensions.

    ! OUTPUT:

    ! Buffer_VG : defined for all coupling variables and all buffer grid points
    ! (including buffer ghost cells).

    ! REVISION HISTORY
    ! 30Dec2011 R. Oran   - initial version

    !USES:
    use IH_ModSize, ONLY: nI, nJ, nK, MinI, MaxI, MinJ, MaxJ, MinK, MaxK
    use IH_ModMain, ONLY: UseB0, BuffR_, BuffPhi_, BuffTheta_
    use IH_ModAdvance, ONLY: State_VGB, UseElectronPressure
    use IH_ModB0, ONLY: B0_DGB
    use IH_ModPhysics, ONLY: &
         No2Si_V, UnitRho_, UnitP_, UnitRhoU_, UnitB_, UnitEnergyDens_
    use IH_ModVarIndexes,     ONLY: &
         Rho_, RhoUx_, RhoUz_, Bx_, Bz_, P_, Pe_, &
         Ppar_, WaveFirst_, WaveLast_, Ehot_, nVar, &
         ChargeStateFirst_, ChargeStateLast_
    use IH_ModBuffer, ONLY:iVar_V, DoCoupleVar_V, nVarCouple
    use CON_coupler,       ONLY: &
         RhoCouple_, RhoUxCouple_,&
         RhoUzCouple_, PCouple_, BxCouple_, BzCouple_,  &
         PeCouple_, PparCouple_, WaveFirstCouple_,  &
         WaveLastCouple_, Bfield_, Wave_, EhotCouple_, &
         AnisoPressure_, ElectronPressure_,&
         CollisionlessHeatFlux_, ChargeStateFirstCouple_, &
         ChargeStateLastCouple_, ChargeState_
    use ModCoordTransform, ONLY: sph_to_xyz
    use ModInterpolate,    ONLY: trilinear
    use IH_BATL_lib,       ONLY: iProc, &
         find_grid_block, xyz_to_coord, CoordMin_DB, CellSize_DB, nDim

    !INPUT ARGUMENTS:
    ! Buffer size and limits
    integer,intent(in) :: nR, nPhi, nTheta
    real, intent(in)   :: TimeCoupling
    real, intent(in)   :: BufferMinMax_DI(nDim,2)
    integer,intent(in) :: iCompSource, iCompTarget

    ! OUTPUT ARGUMENTS
    ! State variables to be fiiled in all buffer grid points
    real,dimension(nVarCouple,nR,0:nPhi+1,0:nTheta+1),intent(out):: Buffer_VG

    ! variables for defining the buffer grid

    integer :: nCell_D(3)
    real    :: SphMin_D(3), SphMax_D(3), dSph_D(3)

    ! Variables for interpolating from a grid block to a buffer grid point

    ! Store complete interpolated state vector
    real :: StateInPoint_V(nVar)

    ! Store interpolated state variables needed for coupling
    real :: Buffer_V(nVarCouple), B0_D(3)

    ! Buffer grid cell center coordinates
    real :: CoordBuffer_D(3), XyzBuffer_D(3)

    ! Buffer grid cell center position  normalized by grid spacing
    ! (in IH_BATSRUS grid generalized coordinates)
    real :: BufferNorm_D(3)

    ! variable indices in buffer
    integer   :: &
         iRhoCouple,              &
         iRhoUxCouple,            &
         iRhoUzCouple,            &   
         iPCouple,                &       
         iPeCouple,               &      
         iPparCouple,             &    
         iBxCouple,               &      
         iBzCouple,               &      
         iWaveFirstCouple,        &
         iWaveLastCouple,         &
         iChargeStateFirstCouple, &
         iChargeStateLastCouple,  &
         iEhotCouple


    integer   :: iPhiNew, iBlock, iPe, iR, iPhi, iTheta
    real      :: r, theta, phi

    ! Variables for testing 
    integer :: i, j ,k
    real    :: State_VG(nVar,-1:nI+2,-1:nJ+2,-1:nK+2), Btot_D(3)
    logical :: DoTest, DoTestMe
    character (len=*), parameter :: StringTest='IH_impose_par_flow_buffer'

    character (len=*), parameter :: NameSub='IH_get_for_buffer_grid'
    !--------------------------------------------------------------------------
    call CON_set_do_test(StringTest,DoTest,DoTestMe)
    if (DoTest .and. iProc == 0) write(*,*) &
         NameSub, ' in test mode: Imposing parallel flow inside buffer grid.'

    Buffer_VG = 0.0

    ! get variable indices in buffer
    iRhoCouple              = iVar_V(RhoCouple_)
    iRhoUxCouple            = iVar_V(RhoUxCouple_)
    iRhoUzCouple            = iVar_V(RhoUzCouple_)
    iPCouple                = iVar_V(PCouple_)
    iPeCouple               = iVar_V(PeCouple_)
    iPparCouple             = iVar_V(PparCouple_)
    iBxCouple               = iVar_V(BxCouple_)
    iBzCouple               = iVar_V(BzCouple_)
    iWaveFirstCouple        = iVar_V(WaveFirstCouple_)
    iWaveLastCouple         = iVar_V(WaveLastCouple_)
    iEhotCouple             = iVar_V(EhotCouple_)
    iChargeStateFirstCouple = iVar_V(ChargeStateFirstCouple_)
    iChargeStateLastCouple  = iVar_V(ChargeStateLastCouple_)

    ! Calculate buffer grid spacing
    nCell_D  = (/nR, nPhi, nTheta/)
    SphMin_D = BufferMinMax_DI(:,1)
    SphMax_D = BufferMinMax_DI(:,2)

    dSph_D     = (SphMax_D - SphMin_D)/real(nCell_D)
    dSph_D(BuffR_) = (SphMax_D(BuffR_) - SphMin_D(BuffR_))/(nCell_D(BuffR_)-1)

    ! Loop over buffer grid points
    do iR = 1, nR ; do iPhi = 1, nPhi ; do iTheta = 1, nTheta

       ! Find the coordinates of the current buffer grid point, 
       r     =  SphMin_D(BuffR_)     + (iR - 1)*dSph_D(BuffR_)
       Phi   =  SphMin_D(BuffPhi_)   + (real(iPhi)-0.5)*dSph_D(BuffPhi_)
       Theta =  SphMin_D(BuffTheta_) + (real(iTheta)-0.5)*dSph_D(BuffTheta_)

       ! Convert to xyz
       call sph_to_xyz(r, Theta, Phi, XyzBuffer_D)

       ! Find the block and PE in the IH_BATSRUS grid
       call find_grid_block(XyzBuffer_D, iPe, iBlock)

       ! Check if this block belongs to this processor
       if (iProc /= iPe) CYCLE

       ! Convert buffer grid point coordinate to IH_BATSRUS generalized coords
       call xyz_to_coord(XyzBuffer_D, CoordBuffer_D)

       ! Buffer grid point position normalized by the grid spacing
       BufferNorm_D = (CoordBuffer_D - CoordMin_DB(:,iBlock)) &
            / CellSize_DB(:,iBlock) + 0.5

       if(DoTest) then
          ! Impose U||B prior to interpolation
          do i=-1,nI+2 ; do j=-1,nJ+2 ; do k=-1, nK+2
             State_VG(:,i,j,k) = State_VGB(:,i,j,k,iBlock)
             Btot_D = State_VGB(Bx_:Bz_,i,j,k,iBlock) + B0_DGB(:,i,j,k,iBlock)

             State_VG(RhoUx_:RhoUz_,i,j,k) = Btot_D*                 &
                  sum(State_VGB(RhoUx_:RhoUz_,i,j,k,iBlock)*Btot_D)/ & 
                  (sum(Btot_D**2)+1e-40)

          end do; end do; end do

          ! Interpolate from the modified state in the block 
          ! to the buffer grid point
          StateInPoint_V = &
               trilinear(State_VG, nVar, MinI, MaxI, MinJ, MaxJ, MinK, MaxK, &
               BufferNorm_D) !, DoExtrapolate = .TRUE.)

       else

          ! Interpolate from the true solution block to the buffer grid point
          StateInPoint_V = &
               trilinear(State_VGB(:,:,:,:,iBlock), &
               nVar, MinI, MaxI, MinJ, MaxJ, MinK, MaxK, &
               BufferNorm_D) !, DoExtrapolate = .TRUE.)
       end if

       ! Fill in the coupled state variables

       Buffer_V(iRhoCouple)= StateInPoint_V(rho_)
       Buffer_V(iRhoUxCouple:iRhoUzCouple) = &
            StateInPoint_V(rhoUx_:rhoUz_)

       if(DoCoupleVar_V(Bfield_)) then
          if(UseB0)then
             B0_D = &
                  trilinear(B0_DGB(:,:,:,:,iBlock), &
                  3, MinI, MaxI, MinJ, MaxJ, MinK, MaxK, &
                  BufferNorm_D, DoExtrapolate = .TRUE.)
             Buffer_V(iBxCouple:iBzCouple) = &
                  StateInPoint_V(Bx_:Bz_) + B0_D
          else
             Buffer_V(iBxCouple:iBzCouple) = &
                  StateInPoint_V(Bx_:Bz_)
          end if
       end if

       if(DoCoupleVar_V(Wave_)) &
            Buffer_V(iWaveFirstCouple:iWaveLastCouple) = &
            StateInPoint_V(WaveFirst_:WaveLast_)

       if(DoCoupleVar_V(ChargeState_)) &
            Buffer_V(iChargeStateFirstCouple:iChargeStateLastCouple) = &
            StateInPoint_V(ChargeStateFirst_:ChargeStateLast_)

       Buffer_V(iPCouple)  = StateInPoint_V(p_) 

       if(DoCoupleVar_V(ElectronPressure_))then
          Buffer_V(iPeCouple) = StateInPoint_V(Pe_)
       else if(UseElectronPressure)then
          Buffer_V(iPCouple) = Buffer_V(iPCouple) + StateInPoint_V(Pe_)
       end if

       if(DoCoupleVar_V(AnisoPressure_)) Buffer_V(iPparCouple) = &
            StateInPoint_V(Ppar_)

       if(DoCoupleVar_V(CollisionlessHeatFlux_)) Buffer_V(iEhotCouple) = &
            StateInPoint_V(Ehot_)

       ! Convert to SI units
       Buffer_V(iRhoCouple) = &
            Buffer_V(iRhoCouple) * No2Si_V(UnitRho_)
       Buffer_V(iRhoUxCouple:iRhoUzCouple)= &
            Buffer_V(iRhoUxCouple:iRhoUzCouple) *No2Si_V(UnitRhoU_)
       Buffer_V(iPCouple) = Buffer_V(iPCouple) * No2Si_V(UnitP_)

       if(DoCoupleVar_V(Bfield_)) Buffer_V(iBxCouple:iBzCouple) = &
            Buffer_V(iBxCouple:iBzCouple)*No2Si_V(UnitB_)

       if(DoCoupleVar_V(Wave_)) &
            Buffer_V(iWaveFirstCouple:iWaveLastCouple) = &
            Buffer_V(iWaveFirstCouple:iWaveLastCouple) &
            * No2Si_V(UnitEnergyDens_)

       if(DoCoupleVar_V(ChargeState_)) &
            Buffer_V(iChargeStateFirstCouple:iChargeStateLastCouple) = &
            Buffer_V(iChargeStateFirstCouple:iChargeStateLastCouple) &
            * No2Si_V(UnitRho_)
       
       if(DoCoupleVar_V(ElectronPressure_)) Buffer_V(iPeCouple) = &
            Buffer_V(iPeCouple)*No2Si_V(UnitP_)

       if(DoCoupleVar_V(AnisoPressure_))Buffer_V(iPparCouple) = &
            Buffer_V(iPparCouple)*No2Si_V(UnitP_)

       if(DoCoupleVar_V(CollisionlessHeatFlux_))Buffer_V(iEhotCouple) = &
            Buffer_V(iEhotCouple)*No2Si_V(UnitEnergyDens_)

       ! ------------------------------------------------------
       !! Perform vector transformations if necessary
       !!        The followinf can be usefull if the source in an inertial
       !!        frame and the target is in a rotating frame.
       !!        WARNING: If you uncomment these lines make sure to disable
       !!                 any transformations done when buffer is read by target (e.g. IH_ModBuffer)
       !! START:
       !
       !if (Grid_C(iCompSource)%TypeCoord /=  &
       !     Grid_C(iCompTarget)%TypeCoord) then
       !   !Transform velocity
       !   ! NOTE: This transformation is only valid for a single fluid
       !   Buffer_V(iRhoUxCouple:iRhoUzCouple)=Buffer_V(iRhoCouple)*&
       !        transform_velocity(TimeCoupling,&
       !        Buffer_V(iRhoUxCouple:iRhoUzCouple)/Buffer_V(iRhoCouple),&
       !        No2Si_V(UnitX_)*XyzBuffer_D,&
       !        Grid_C(iCompSource)%TypeCoord,&
       !        Grid_C(iCompTarget)%TypeCoord)
       !
       !   ! Transform magnetic field
       !   SourceToTarget_DD = transform_matrix(TimeCoupling, &
       !        Grid_C(iCompSource)%TypeCoord, Grid_C(iCompTarget)%TypeCoord)

       !   Buffer_V(iBxCouple:iBzCouple) = &
       !        matmul(SourceToTarget_DD,Buffer_V(iBxCouple:iBzCouple))
       !end if
       !! END vector transformation

       ! DONE - fill the buffer grid
       Buffer_VG(:,iR, iPhi,iTheta) = Buffer_V

    end do; end do; end do

    ! Fill buffer grid ghost cells
    do iPhi = 1, nPhi 
       iPhiNew = iPhi + nPhi/2
       if (iPhiNew > nPhi) iPhiNew = iPhiNew - nPhi
       Buffer_VG(:,:,iPhi, 0) = Buffer_VG(:,:,iPhiNew, 1)
       Buffer_VG(:,:,iPhi,nTheta+1) = Buffer_VG(:,:,iPhiNew, nTheta)
    end do
    Buffer_VG(:,:,0,:) = Buffer_VG(:,:,nPhi,:)
    Buffer_VG(:,:,nPhi+1,:) = Buffer_VG(:,:,1,:)
  end subroutine IH_get_for_global_buffer

  !============================================================================

  subroutine IH_get_for_mh(nPartial,iGetStart,Get,W,State_V,nVar)

    !USES:
    use IH_ModAdvance, ONLY: State_VGB, UseElectronPressure
    use IH_ModB0,      ONLY: B0_DGB
    use IH_ModPhysics, ONLY: No2Si_V, UnitRho_, UnitP_, UnitRhoU_, UnitB_
    use IH_ModPhysics, ONLY: UnitEnergyDens_
    use IH_ModAdvance, ONLY: Rho_, RhoUx_, RhoUz_, Bx_, Bz_, P_, WaveFirst_, &
         WaveLast_, Pe_, Ppar_, Ehot_, ChargeStateFirst_, ChargeStateLast_
    use IH_ModMain,    ONLY: UseB0

    use CON_router, ONLY: IndexPtrType, WeightPtrType
    use CON_coupler,ONLY: iVar_V, DoCoupleVar_V, &
         RhoCouple_, RhoUxCouple_, &
         RhoUzCouple_, PCouple_, BxCouple_, BzCouple_, PeCouple_, PparCouple_,&
         WaveFirstCouple_, WaveLastCouple_, Bfield_, Wave_, AnisoPressure_, &
         ElectronPressure_, EhotCouple_, Momentum_, &
         CollisionlessHeatFlux_, ChargeStateFirstCouple_, &
         ChargeStateLastCouple_, ChargeState_

    !INPUT ARGUMENTS:
    integer,intent(in)              ::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)   ::Get
    type(WeightPtrType),intent(in)  ::W
    real,dimension(nVar),intent(out)::State_V

    integer   :: iGet, i, j, k, iBlock
    real      :: Weight
    integer   :: &
         iRhoCouple,              &
         iRhoUxCouple,            &
         iRhoUzCouple,            &   
         iPCouple,                &       
         iPeCouple,               &      
         iPparCouple,             &    
         iBxCouple,               &      
         iBzCouple,               &      
         iWaveFirstCouple,        &
         iWaveLastCouple,         &
         iChargeStateFirstCouple, &
         iChargeStateLastCouple,  &
         iEhotCouple

    character (len=*), parameter :: NameSub='IH_get_for_mh'

    ! 'Safety' parameter, to keep the coupler toolkit unchanged
    ! Useless, to my mind.
    !--------------------------------------------------------------------------
    ! get variable indices in buffer
    iRhoCouple       = iVar_V(RhoCouple_)
    iRhoUxCouple     = iVar_V(RhoUxCouple_)
    iRhoUzCouple     = iVar_V(RhoUzCouple_)
    iPCouple         = iVar_V(PCouple_)
    iPeCouple        = iVar_V(PeCouple_)
    iPparCouple      = iVar_V(PparCouple_)
    iBxCouple        = iVar_V(BxCouple_)
    iBzCouple        = iVar_V(BzCouple_)
    iWaveFirstCouple = iVar_V(WaveFirstCouple_)
    iWaveLastCouple  = iVar_V(WaveLastCouple_)
    iChargeStateFirstCouple = iVar_V(ChargeStateFirstCouple_)
    iChargeStateLastCouple  = iVar_V(ChargeStateLastCouple_)
    iEhotCouple      = iVar_V(EhotCouple_)

    i      = Get%iCB_II(1,iGetStart)
    j      = Get%iCB_II(2,iGetStart)
    k      = Get%iCB_II(3,iGetStart)
    iBlock = Get%iCB_II(4,iGetStart)
    Weight = W%Weight_I(iGetStart)

    State_V(iRhoCouple)= State_VGB(rho_,i,j,k,iBlock)*Weight
    if(DoCoupleVar_V(Momentum_))State_V(iRhoUxCouple:iRhoUzCouple) = &
         State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock)*Weight

    if(DoCoupleVar_V(Bfield_)) then
       if(UseB0)then
          State_V(iBxCouple:iBzCouple) = &
               (State_VGB(Bx_:Bz_,i,j,k,iBlock)+ B0_DGB(:,i,j,k,iBlock))*Weight
       else
          State_V(iBxCouple:iBzCouple) = &
               State_VGB(Bx_:Bz_,i,j,k,iBlock)*Weight
       end if
    end if

    if(DoCoupleVar_V(Wave_)) &
         State_V(iWaveFirstCouple:iWaveLastCouple) = &
         State_VGB(WaveFirst_:WaveLast_,i,j,k,iBlock)*Weight

    if(DoCoupleVar_V(ChargeState_)) &
         State_V(iChargeStateFirstCouple:iChargeStateLastCouple) = &
         State_VGB(ChargeStateFirst_:ChargeStateLast_,i,j,k,iBlock)*Weight
    
    State_V(iPCouple)  = State_VGB(p_,i,j,k,iBlock) *Weight

    if(DoCoupleVar_V(ElectronPressure_))then
       State_V(iPeCouple) = &
            State_VGB(Pe_,i,j,k,iBlock)*Weight
    else if(UseElectronPressure)then
       State_V(iPCouple) = &
            State_V(iPCouple) + State_VGB(Pe_,i,j,k,iBlock)*Weight
    end if

    if(DoCoupleVar_V(AnisoPressure_)) State_V(iPparCouple) = &
         State_VGB(Ppar_,i,j,k,iBlock)*Weight

    if(DoCoupleVar_V(CollisionlessHeatFlux_)) State_V(iEhotCouple) = &
         State_VGB(Ehot_,i,j,k,iBlock)*Weight

    do iGet=iGetStart+1,iGetStart+nPartial-1
       i      = Get%iCB_II(1,iGet)
       j      = Get%iCB_II(2,iGet)
       k      = Get%iCB_II(3,iGet)
       iBlock = Get%iCB_II(4,iGet)
       Weight = W%Weight_I(iGet)

       State_V(iRhoCouple) = &
            State_V(iRhoCouple) + &
            State_VGB(rho_,i,j,k,iBlock)*Weight 
        if(DoCoupleVar_V(Momentum_))State_V(iRhoUxCouple:iRhoUzCouple) = &
            State_V(iRhoUxCouple:iRhoUzCouple) + &
            State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock) *Weight
       if(DoCoupleVar_V(Bfield_)) then
          if(UseB0)then
             State_V(iBxCouple:iBzCouple) = &
                  State_V(iBxCouple:iBzCouple) + &
                  (State_VGB(Bx_:Bz_,i,j,k,iBlock) + &
                  B0_DGB(:,i,j,k,iBlock))*Weight
          else 
             State_V(iBxCouple:iBzCouple) = &
                  State_V(iBxCouple:iBzCouple) + &
                  State_VGB(Bx_:Bz_,i,j,k,iBlock)*Weight
          end if
       end if

       if(DoCoupleVar_V(Wave_)) &
            State_V(iWaveFirstCouple:iWaveLastCouple) = &
            State_V(iWaveFirstCouple:iWaveLastCouple) + &
            State_VGB(WaveFirst_:WaveLast_,i,j,k,iBlock)*Weight

       if(DoCoupleVar_V(ChargeState_)) &
            State_V(iChargeStateFirstCouple:iChargeStateLastCouple) = &
            State_V(iChargeStateFirstCouple:iChargeStateLastCouple) + &
            State_VGB(ChargeStateFirst_:ChargeStateLast_,i,j,k,iBlock)*Weight
       
       if(DoCoupleVar_V(AnisoPressure_)) State_V(iPparCouple) = &
            State_V(iPparCouple) + &
            State_VGB(Ppar_,i,j,k,iBlock)*Weight

       if(DoCoupleVar_V(CollisionlessHeatFlux_)) State_V(iEhotCouple) = &
            State_V(iEhotCouple) + &
            State_VGB(Ehot_,i,j,k,iBlock)*Weight

       if(DoCoupleVar_V(ElectronPressure_))then
          State_V(iPeCouple) = State_V(iPeCouple) + &
               State_VGB(Pe_,i,j,k,iBlock)*Weight
          State_V(iPCouple) = State_V(iPCouple) + &
               State_VGB(p_,i,j,k,iBlock) *Weight

       else if(UseElectronPressure)then
          State_V(iPCouple) = State_V(iPCouple) &
               + (State_VGB(p_,i,j,k,iBlock) + &
               State_VGB(Pe_,i,j,k,iBlock))*Weight
       else
          State_V(iPCouple) = State_V(iPCouple) + &
               State_VGB(p_,i,j,k,iBlock) *Weight
       end if
    end do

    ! Convert to SI units
    State_V(iRhoCouple) = &
         State_V(iRhoCouple) * No2Si_V(UnitRho_)
    if(DoCoupleVar_V(Momentum_))State_V(iRhoUxCouple:iRhoUzCouple)= &
         State_V(iRhoUxCouple:iRhoUzCouple) *No2Si_V(UnitRhoU_)
    State_V(iPCouple) = State_V(iPCouple) * No2Si_V(UnitP_)

    if(DoCoupleVar_V(Bfield_)) State_V(iBxCouple:iBzCouple) = &
         State_V(iBxCouple:iBzCouple)*No2Si_V(UnitB_)

    if(DoCoupleVar_V(Wave_)) &
         State_V(iWaveFirstCouple:iWaveLastCouple) = &
         State_V(iWaveFirstCouple:iWaveLastCouple) &
         * No2Si_V(UnitEnergyDens_)

    if(DoCoupleVar_V(ChargeState_)) &
         State_V(iChargeStateFirstCouple:iChargeStateLastCouple) = &
         State_V(iChargeStateFirstCouple:iChargeStateLastCouple) &
         * No2Si_V(UnitRho_)
    
    if(DoCoupleVar_V(ElectronPressure_)) State_V(iPeCouple) = &
         State_V(iPeCouple)*No2Si_V(UnitP_)

    if(DoCoupleVar_V(AnisoPressure_))State_V(iPparCouple) = &
         State_V(iPparCouple)*No2Si_V(UnitP_)

    if(DoCoupleVar_V(CollisionlessHeatFlux_))State_V(iEhotCouple) = &
         State_V(iEhotCouple)*No2Si_V(UnitEnergyDens_)

  end subroutine IH_get_for_mh
  !============================================================================

  subroutine IH_extract_line(Xyz_DI, iTraceMode, &
       iIndex_II, RSoftBoundary)
    use IH_BATL_lib, ONLY: nDim
    use IH_ModParticleFieldLine, &
         ONLY: extract_particle_line, RSoftBoundaryBats=>RSoftBoundary
    real,             intent(in) :: Xyz_DI(:,:)
    integer,          intent(in) :: iTraceMode
    integer,          intent(in) :: iIndex_II(:,:)
    real,             intent(in) :: RSoftBoundary
    character(len=*), parameter  :: NameSub='IH_extract_line'
    !--------------------------------------------------------------------------
    ! set the soft boundary 
         RSoftBoundaryBats = RSoftBoundary
    ! extract field lines starting at input points
    call extract_particle_line(Xyz_DI,iTraceMode,iIndex_II,&
         UseInputInGenCoord=.true.)
  end subroutine IH_extract_line

  !============================================================================

  subroutine IH_put_particles(Xyz_DI, iIndex_II)
    use IH_BATL_lib, ONLY: nDim, put_particles
    use IH_ModParticleFieldLine, ONLY: KindReg_
    ! add particles with specified coordinates to the already existing lines
    real,    intent(in):: Xyz_DI(:,:)
    integer, intent(in):: iIndex_II(:,:)
    !------------------------------------------------------------------------
    call put_particles(&
         iKindParticle      = KindReg_ ,&
         StateIn_VI         = Xyz_DI   ,&
         iIndexIn_II        = iIndex_II,&
         UseInputInGenCoord = .true.   ,&
         DoReplace          = .true.     )
  end subroutine IH_put_particles
  !=====================================
  subroutine IH_get_particle_indexes(iParticle, iIndex_I)
    use IH_ModParticleFieldLine, ONLY: fl_, id_, KindReg_
    use IH_BATL_particles, ONLY: Particle_I
    integer, intent(in) :: iParticle
    integer, intent(out):: iIndex_I(2)
    character(len=*), parameter:: NameSub='IH_get_particle_indexes'
    !---------------------------------------
    iIndex_I(1) = Particle_I(KindReg_)%iIndex_II(fl_, iParticle)
    iIndex_I(2) = Particle_I(KindReg_)%iIndex_II(id_, iParticle)
  end subroutine IH_get_particle_indexes
  !====================================
  subroutine IH_get_particle_coords(iParticle, Xyz_D)
    use IH_BATL_lib, ONLY: nDim
    use IH_ModParticleFieldLine, ONLY: KindReg_
    use IH_BATL_particles, ONLY: Particle_I
    integer, intent(in) :: iParticle
    real,    intent(out):: Xyz_D(nDim)
    !--------------------------------------------------------------
    Xyz_D = Particle_I(KindReg_)%State_VI(1:nDim, iParticle)
  end subroutine IH_get_particle_coords
  !============================================================================
  !BOP
  !ROUTINE: IH_put_from_mh - transform and put the data got from MH
  !INTERFACE:
  subroutine IH_put_from_mh(nPartial,&
       iPutStart,&
       Put,& 
       Weight,&
       DoAdd,&
       StateSI_V,&
       nVar)
    !USES:
    use CON_router,    ONLY: IndexPtrType, WeightPtrType
    use CON_coupler,   ONLY: iVar_V, DoCoupleVar_V, &
         RhoCouple_, RhoUxCouple_, RhoUzCouple_, &
         PCouple_, BxCouple_, BzCouple_, PeCouple_, EhotCouple_, &
         PparCouple_, WaveFirstCouple_, WaveLastCouple_, &
         Bfield_, Wave_, ElectronPressure_, AnisoPressure_, &
         CollisionlessHeatFlux_, ChargeStateFirstCouple_, &
         ChargeStateLastCouple_, ChargeState_
    use IH_ModAdvance,    ONLY: State_VGB, UseElectronPressure, &
         UseAnisoPressure
    use IH_ModB0,         ONLY: B0_DGB
    use IH_ModPhysics,    ONLY: Si2No_V, UnitRho_, UnitP_, UnitRhoU_, UnitB_, &
         UnitEnergyDens_
    use IH_ModMain,       ONLY: UseB0
    use IH_ModVarIndexes, ONLY: Rho_, RhoUx_, RhoUz_, Bx_, Bz_, P_, &
         WaveFirst_, WaveLast_, Pe_, Ppar_, Ehot_, ChargeStateFirst_, &
         ChargeStateLast_

    !INPUT ARGUMENTS:
    integer,intent(in)::nPartial,iPutStart,nVar
    type(IndexPtrType),intent(in)::Put
    type(WeightPtrType),intent(in)::Weight
    logical,intent(in)::DoAdd
    real,dimension(nVar),intent(in)::StateSI_V

    !REVISION HISTORY:
    !18JUL03     I.Sokolov <igorsok@umich.edu> - intial prototype/code
    !23AUG03                                     prolog
    !03SEP03     G.Toth    <gtoth@umich.edu>   - simplified
    !05APR11     R. Oran   <oran@umich.edu>    - Use non-fixed coupling indices
    !                                          derived by the coupler according
    !                                           to actual variable names
    !                                           (see use CON_coupler).
    !                                           Handle anisotropic pressure.
    !                                 
    !EOP

    character (len=*), parameter :: NameSub='IH_put_from_mh'

    real,dimension(nVar)::State_V
    integer             :: i, j, k, iBlock
    integer   :: &
         iRhoCouple,              &
         iRhoUxCouple,            &
         iRhoUzCouple,            &
         iPCouple,                &
         iPeCouple,               &
         iPparCouple,             &
         iBxCouple,               &
         iBzCouple,               &
         iWaveFirstCouple,        &
         iWaveLastCouple,         &
         iChargeStateFirstCouple, &
         iChargeStateLastCouple,  &
         iEhotCouple

    !--------------------------------------------------------------------------
    ! get variable indices in buffer
    iRhoCouple       = iVar_V(RhoCouple_)
    iRhoUxCouple     = iVar_V(RhoUxCouple_)
    iRhoUzCouple     = iVar_V(RhoUzCouple_)
    iPCouple         = iVar_V(PCouple_)
    iPeCouple        = iVar_V(PeCouple_)
    iPparCouple      = iVar_V(PparCouple_)
    iBxCouple        = iVar_V(BxCouple_)
    iBzCouple        = iVar_V(BzCouple_)
    iWaveFirstCouple = iVar_V(WaveFirstCouple_)
    iWaveLastCouple  = iVar_V(WaveLastCouple_)
    iChargeStateFirstCouple = iVar_V(ChargeStateFirstCouple_)
    iChargeStateLastCouple  = iVar_V(ChargeStateLastCouple_)
    iEhotCouple      = iVar_V(EhotCouple_)

    ! Convert state variable in buffer to nirmalized units.
    State_V(iRhoCouple) = StateSI_V(iRhoCouple) * Si2No_V(UnitRho_)

    State_V(iRhoUxCouple:iRhoUzCouple) = &
         StateSI_V(iRhoUxCouple:iRhoUzCouple) * Si2No_V(UnitRhoU_)

    State_V(iPCouple) = StateSI_V(iPCouple) * Si2No_V(UnitP_)

    if(DoCoupleVar_V(Bfield_)) State_V(iBxCouple:iBzCouple) = &
         StateSI_V(iBxCouple:iBzCouple)* Si2No_V(UnitB_)

    if(DoCoupleVar_V(Wave_)) &
         State_V(iWaveFirstCouple:iWaveLastCouple) = &
         StateSI_V(iWaveFirstCouple:iWaveLastCouple) &
         * Si2No_V(UnitEnergyDens_)

    if(DoCoupleVar_V(ChargeState_)) &
         State_V(iChargeStateFirstCouple:iChargeStateLastCouple) = &
         StateSI_V(iChargeStateFirstCouple:iChargeStateLastCouple) &
         * Si2No_V(UnitRho_)

    if(DoCoupleVar_V(ElectronPressure_))State_V(iPeCouple) = &
         StateSI_V(iPeCouple)*Si2No_V(UnitP_)

    if(DoCoupleVar_V(AnisoPressure_)) State_V(iPparCouple) = &
         StateSI_V(iPparCouple)*Si2No_V(UnitP_)

    if(DoCoupleVar_V(CollisionlessHeatFlux_)) State_V(iEhotCouple) = &
         StateSI_V(iEhotCouple)*Si2No_V(UnitEnergyDens_)

    i      = Put%iCB_II(1,iPutStart)
    j      = Put%iCB_II(2,iPutStart)
    k      = Put%iCB_II(3,iPutStart)
    iBlock = Put%iCB_II(4,iPutStart)

    if(DoAdd)then
       State_VGB(rho_,i,j,k,iBlock) = &
            State_VGB(rho_,i,j,k,iBlock) + &
            State_V(iRhoCouple)

       State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock) = &
            State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock) + &
            State_V(iRhoUxCouple:iRhoUzCouple)

       if (DoCoupleVar_V(Bfield_)) State_VGB(Bx_:Bz_,i,j,k,iBlock) = &
            State_VGB(Bx_:Bz_,i,j,k,iBlock) + &
            State_V(iBxCouple:iBzCouple)

       if(DoCoupleVar_V(Wave_)) &
            State_VGB(WaveFirst_:WaveLast_,i,j,k,iBlock) = &
            State_VGB(WaveFirst_:WaveLast_,i,j,k,iBlock) + &
            State_V(iWaveFirstCouple:iWaveLastCouple)

       if(DoCoupleVar_V(ChargeState_)) &
            State_VGB(ChargeStateFirst_:ChargeStateLast_,i,j,k,iBlock) = &
            State_VGB(ChargeStateFirst_:ChargeStateLast_,i,j,k,iBlock) + &
            State_V(iChargeStateFirstCouple:iChargeStateLastCouple)

       if(DoCoupleVar_V(ElectronPressure_))then
          State_VGB(Pe_,i,j,k,iBlock) = &
               State_VGB(Pe_,i,j,k,iBlock) + State_V(iPeCouple)
          State_VGB(p_,i,j,k,iBlock) = State_VGB(p_,i,j,k,iBlock) &
               + State_V(iPCouple)
       else if(UseElectronPressure)then
          State_VGB(Pe_,i,j,k,iBlock) = State_VGB(Pe_,i,j,k,iBlock) &
               + 0.5*State_V(iPCouple)
          ! correct pressure state variable
          State_VGB(p_,i,j,k,iBlock) = State_VGB(p_,i,j,k,iBlock) &
               + 0.5*State_V(iPCouple)
       else
          State_VGB(p_,i,j,k,iBlock) = State_VGB(p_,i,j,k,iBlock) &
               +State_V(iPCouple)
       end if

       if(DoCoupleVar_V(AnisoPressure_))then
          State_VGB(Ppar_,i,j,k,iBlock) = &
               State_VGB(Ppar_,i,j,k,iBlock) + State_V(iPparCouple)
       else if(UseAnisoPressure)then
          State_VGB(Ppar_,i,j,k,iBlock) = State_VGB(Ppar_,i,j,k,iBlock) &
               + State_V(iPCouple)
       end if

       if(DoCoupleVar_V(CollisionlessHeatFlux_))then
          State_VGB(Ehot_,i,j,k,iBlock) = &
               State_VGB(Ehot_,i,j,k,iBlock) + State_V(iEhotCouple)
       endif

    else

       State_VGB(rho_,i,j,k,iBlock)= State_V(iRhoCouple)
       State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock) = &
            State_V(iRhoUxCouple:iRhoUzCouple)

       if(DoCoupleVar_V(Bfield_)) then
          if(UseB0)then
             State_VGB(Bx_:Bz_,i,j,k,iBlock) = &
                  State_V(iBxCouple:iBzCouple) - &
                  B0_DGB(:,i,j,k,iBlock)
          else
             State_VGB(Bx_:Bz_,i,j,k,iBlock) = &
                  State_V(iBxCouple:iBzCouple)
          end if
       end if

       if(DoCoupleVar_V(Wave_))State_VGB(WaveFirst_:WaveLast_,i,j,k,iBlock) = &
            State_V(iWaveFirstCouple:iWaveLastCouple)

       if(DoCoupleVar_V(ChargeState_))&
            State_VGB(ChargeStateFirst_:ChargeStateLast_,i,j,k,iBlock) = &
            State_V(iChargeStateFirstCouple:iChargeStateLastCouple)
       
       State_VGB(p_,i,j,k,iBlock) = State_V(iPCouple)
       if(DoCoupleVar_V(AnisoPressure_))then
          State_VGB(Ppar_,i,j,k,iBlock) = State_V(iPparCouple)
       else if(UseAnisoPressure)then
          State_VGB(Ppar_,i,j,k,iBlock) = State_V(iPCouple)
       end if

       if(DoCoupleVar_V(CollisionlessHeatFlux_))then
          State_VGB(Ehot_,i,j,k,iBlock) = State_V(iEhotCouple)
       endif

       if(DoCoupleVar_V(ElectronPressure_))then
          State_VGB(Pe_,i,j,k,iBlock) = State_V(iPeCouple)
       else if(UseElectronPressure)then
          State_VGB(Pe_,i,j,k,iBlock) = 0.5*State_V(iPCouple)
          State_VGB(p_,i,j,k,iBlock) = 0.5*State_V(iPCouple)
       end if
    end if

  end subroutine IH_put_from_mh

  !============================================================================
  subroutine IH_check_ready_for_sp(IsReady)
    use ModMpi
    use CON_coupler, ONLY: is_proc0, i_proc0, i_comm
    use IH_ModParticleFieldLine, ONLY: UseParticles
    logical, intent(out):: IsReady

    integer :: iError
    !------------------------------------------------
    ! get value at IH root and broadcast to all SWMF processors
    if(is_proc0(IH_)) &
         IsReady = UseParticles
    call MPI_Bcast(IsReady, 1, MPI_LOGICAL, i_proc0(IH_), i_comm(), iError)
  end subroutine IH_check_ready_for_sp
  !============================================================================

  subroutine IH_get_for_gm(&
       nPartial,iGetStart,Get,W,State_V,nVar,TimeCoupling)

    !USES:
    use IH_ModAdvance, ONLY: State_VGB, Rho_, RhoUx_, RhoUz_, Bx_, Bz_,P_
    use IH_ModB0,      ONLY: B0_DGB
    use IH_ModPhysics, ONLY: No2Si_V, UnitRho_, UnitP_, UnitRhoU_, UnitB_
    use IH_ModMain,    ONLY: UseRotatingFrame,UseB0
    use CON_router

    !INPUT ARGUMENTS:
    integer,intent(in)::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)::Get
    type(WeightPtrType),intent(in)::W
    real,dimension(nVar),intent(out)::State_V
    real,intent(in)::TimeCoupling

    integer::iGet, i, j, k, iBlock
    real :: Weight, Momentum_D(3),Density

    character (len=*), parameter :: NameSub='IH_get_for_gm'
    !The meaning of state intdex in buffer and in model can be 
    !different. Below are the conventions for buffer:
    integer,parameter::&
         BuffRho_  =1,&
         BuffRhoUx_=2,&
         BuffRhoUz_=4,&
         BuffBx_   =5,&
         BuffBz_   =7,&
         BuffP_    =8


    !----------------------------------------------------------

    i      = Get%iCB_II(1,iGetStart)
    j      = Get%iCB_II(2,iGetStart)
    k      = Get%iCB_II(3,iGetStart)
    iBlock = Get%iCB_II(4,iGetStart)
    Weight = W%Weight_I(iGetStart)

    Density= State_VGB(rho_,         i,j,k,iBlock)
    State_V(BuffRho_)          = Density*Weight

    Momentum_D=State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock)
    if(UseRotatingFrame)call add_density_omega_cross_r

    State_V(BuffRhoUx_:BuffRhoUz_) = Momentum_D*Weight
    if(UseB0)then
       State_V(BuffBx_:BuffBz_) = &
            (State_VGB(Bx_:Bz_,i,j,k,iBlock) + B0_DGB(:,i,j,k,iBlock))*Weight
    else
       State_V(BuffBx_:BuffBz_) = &
            State_VGB(Bx_:Bz_,i,j,k,iBlock)*Weight
    end if

    State_V(BuffP_)  = State_VGB(P_,i,j,k,iBlock)*Weight

    do iGet=iGetStart+1,iGetStart+nPartial-1
       i      = Get%iCB_II(1,iGet)
       j      = Get%iCB_II(2,iGet)
       k      = Get%iCB_II(3,iGet)
       iBlock = Get%iCB_II(4,iGet)
       Weight = W%Weight_I(iGet)

       Density = State_VGB(rho_,i,j,k,iBlock) 
       State_V(BuffRho_)=State_V(BuffRho_) + Density*Weight

       Momentum_D = State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock)

       if(UseRotatingFrame)call add_density_omega_cross_r

       State_V(BuffRhoUx_:BuffRhoUz_) = State_V(BuffRhoUx_:BuffRhoUz_) &
            + Momentum_D*Weight
       if(UseB0)then
          State_V(BuffBx_:BuffBz_) = State_V(BuffBx_:BuffBz_) &
               + (State_VGB(Bx_:Bz_,i,j,k,iBlock) &
               + B0_DGB(:,i,j,k,iBlock))*Weight
       else
          State_V(BuffBx_:BuffBz_) = State_V(BuffBx_:BuffBz_) &
               + State_VGB(Bx_:Bz_,i,j,k,iBlock)*Weight
       end if
       State_V(BuffP_) = State_V(BuffP_) &
            + State_VGB(P_,i,j,k,iBlock)*Weight
    end do

    ! Convert to SI units
    State_V(BuffRho_)             = State_V(BuffRho_)       *No2Si_V(UnitRho_)
    State_V(BuffRhoUx_:BuffRhoUz_)= &
         State_V(BuffRhoUx_:BuffRhoUz_)                     *No2Si_V(UnitRhoU_)
    State_V(BuffBx_:BuffBz_)      = State_V(BuffBx_:BuffBz_)*No2Si_V(UnitB_)
    State_V(BuffP_)               = State_V(BuffP_)         *No2Si_V(UnitP_)

  contains
    !==========================================================================
    subroutine add_density_omega_cross_r
      ! Add Omega x R term. For IH Omega_D = (0,0,OmegaBody)
      use IH_BATL_lib,    ONLY: Xyz_DGB, x_, y_
      use IH_ModPhysics,  ONLY: OmegaBody
      !------------------------------------------------------------------------
      Momentum_D(x_) = Momentum_D(x_) &
           - Density*OmegaBody*Xyz_DGB(y_,i,j,k,iBlock)
      Momentum_D(y_)= Momentum_D(y_) &
           + Density*OmegaBody*Xyz_DGB(x_,i,j,k,iBlock)
    end subroutine add_density_omega_cross_r

  end subroutine IH_get_for_gm

  !============================================================================
  subroutine IH_get_for_pt(IsNew, NameVar, nVarIn, nDimIn, nPoint, Xyz_DI, &
       Data_VI)
    
    ! This routine is actually for OH-PT coupling

    ! Interpolate Data_VI from OH at the list of positions Xyz_DI 
    ! required by PT

    logical,          intent(in):: IsNew   ! true for new point array
    character(len=*), intent(in):: NameVar ! List of variables
    integer,          intent(in):: nVarIn  ! Number of variables in Data_VI
    integer,          intent(in):: nDimIn  ! Dimensionality of positions
    integer,          intent(in):: nPoint  ! Number of points in Xyz_DI

    real, intent(in) :: Xyz_DI(nDimIn,nPoint)  ! Position vectors
    real, intent(out):: Data_VI(nVarIn,nPoint) ! Data array

    ! Optimize search by storing indexes and distances
    integer, allocatable, save:: iBlockCell_DI(:,:)
    real,    allocatable, save:: Dist_DI(:,:)
    !-----------------------------------------------------------------------
    call IH_get_point_data(iBlockCell_DI, Dist_DI, IsNew, &
         NameVar, nVarIn, nDimIn, nPoint, Xyz_DI, Data_VI, &
         DoSendAllVar=.true.)

  end subroutine IH_get_for_pt
  !===========================================================================
  subroutine IH_put_from_pt( &
       NameVar, nVarData, nPoint, Data_VI, iPoint_I, Pos_DI)

    use IH_BATL_lib,    ONLY: &
         nDim, nBlock, MaxBlock, Unused_B, nI, nJ, nK, Xyz_DGB, &
         iTest, jTest, kTest, iBlockTest
    use IH_ModPhysics, ONLY: &
         No2Si_V, Si2No_V, UnitX_, UnitRho_, UnitN_, UnitRhoU_, UnitEnergyDens_, UnitT_
    use IH_ModGeometry, ONLY: true_cell
    use IH_ModAdvance, ONLY: ExtraSource_ICB

    character(len=*), intent(inout):: NameVar  ! List of variables
    integer,          intent(inout):: nVarData ! Number of variables in Data_VI
    integer,          intent(inout):: nPoint   ! Number of points in Pos_DI

    real,    intent(in), optional:: Data_VI(:,:)    ! Recv data array
    integer, intent(in), optional:: iPoint_I(nPoint)! Order of data
    real, intent(out), allocatable, optional:: Pos_DI(:,:)  ! Position vectors

    ! For unit conversion
    real, allocatable, save:: Si2No_I(:) 

    integer:: i, j, k, iBlock, iPoint, iVar

    logical:: DoTest, DoTestMe
    character(len=*), parameter :: NameSub='IH_put_from_pt'
    !--------------------------------------------------------------------------
    call CON_set_do_test(NameSub, DoTest, DoTestMe)
    if(DoTestMe)write(*,*) NameSub,' starting with present(Data_VI)=', &
         present(Data_VI)

    if(.not. present(Data_VI))then
       ! Provide BATSRUS grid points to PT

       nPoint = 0
       do iBlock = 1, nBlock
          if(Unused_B(iBlock)) CYCLE
          do k = 1, nK; do j = 1, nJ; do i = 1, nI
             if(.not.true_cell(i,j,k,iBlock)) CYCLE
             nPoint = nPoint + 1
          end do; end do; end do
       end do

       if(allocated(Pos_DI)) deallocate(Pos_DI)
       allocate(Pos_DI(nDim,nPoint))

       iPoint = 0
       do iBlock = 1, nBlock
          if(Unused_B(iBlock)) CYCLE

          do k = 1, nK; do j = 1, nJ; do i = 1, nI
             if(.not.true_cell(i,j,k,iBlock)) CYCLE
             iPoint = iPoint + 1
             Pos_DI(1:nDim,iPoint) = &
                  Xyz_DGB(1:nDim,i,j,k,iBlock)*No2Si_V(UnitX_)
          end do; end do; end do
       end do

       if(DoTestMe)write(*,*) NameSub,' finished setting positions'

       RETURN
    end if

    ! set source terms due to neutral charge exchange
    if(.not.allocated(Si2No_I))then
       ! Set units for density, momentum and energy source terms
       allocate(Si2No_I(nVarData))
       do iVar = 1, nVarData, 5
          Si2No_I(iVar)          = Si2No_V(UnitRho_)/Si2No_V(UnitT_)/Si2No_V(UnitN_)
          Si2No_I(iVar+1:iVar+3) = Si2No_V(UnitRhoU_)/Si2No_V(UnitT_)/Si2No_V(UnitN_)
          Si2No_I(iVar+4)        = Si2No_V(UnitEnergyDens_)/Si2No_V(UnitT_)/Si2No_V(UnitN_)
       end do
    end if

    if(.not.allocated(ExtraSource_ICB)) &
         allocate(ExtraSource_ICB(nVarData,nI,nJ,nK,MaxBlock))

    iPoint = 0
    do iBlock = 1, nBlock
       if(Unused_B(iBlock)) CYCLE
       
       do k = 1, nK; do j = 1, nJ; do i = 1, nI
          if(.not.true_cell(i,j,k,iBlock)) CYCLE
          iPoint = iPoint + 1
          if(iPoint_I(iPoint) < 0) &
               call CON_stop(NameSub//': IH point is outside of PT domain')
          ExtraSource_ICB(:,i,j,k,iBlock) = Data_VI(:,iPoint_I(iPoint))*Si2No_I
       end do; end do; end do
    end do

    if(DoTestMe)write(*,*) NameSub,' finished with source=', &
         ExtraSource_ICB(:,iTest,jTest,kTest,iBlockTest)

  end subroutine IH_put_from_pt
  !===========================================================================
  subroutine IH_get_for_pt_dt(DtSi)
    ! Calculate the global time step for PC
    use IH_ModMain,            ONLY: Dt
    use IH_ModPhysics,         ONLY: No2Si_V, UnitT_
    use IH_ModTimeStepControl, ONLY: set_global_timestep

    real, intent(out) ::  DtSi
    !--------------------------------------------------------------------------
    ! use -1.0 so that no limit is applied on Dt
    call set_global_timestep(TimeSimulationLimit=-1.0)
    DtSi = Dt*No2Si_V(UnitT_)
  end subroutine IH_get_for_pt_dt
  !===========================================================================
  subroutine IH_get_for_sc(IsNew, NameVar, nVarIn, nDimIn, nPoint, Xyz_DI, &
       Data_VI)

    ! Interpolate Data_VI from EE at the list of positions Xyz_DI 
    ! required by SC

    use IH_ModPhysics, ONLY: Si2No_V, UnitX_, No2Si_V, iUnitCons_V
    use IH_ModAdvance, ONLY: State_VGB, Bx_, Bz_
    use IH_ModVarIndexes, ONLY: nVar
    use IH_ModB0,      ONLY: UseB0, get_b0
    use IH_BATL_lib,   ONLY: iProc, nDim, MaxDim, MinIJK_D, MaxIJK_D, &
         find_grid_block
    use IH_ModIO, ONLY: iUnitOut
    use ModInterpolate, ONLY: interpolate_vector

    logical,          intent(in):: IsNew   ! true for new point array
    character(len=*), intent(in):: NameVar ! List of variables
    integer,          intent(in):: nVarIn  ! Number of variables in Data_VI
    integer,          intent(in):: nDimIn  ! Dimensionality of positions
    integer,          intent(in):: nPoint  ! Number of points in Xyz_DI

    real, intent(in) :: Xyz_DI(nDimIn,nPoint)  ! Position vectors
    real, intent(out):: Data_VI(nVarIn,nPoint) ! Data array

    real:: Xyz_D(MaxDim), B0_D(MaxDim)
    real:: Dist_D(MaxDim), State_V(nVar)
    integer:: iCell_D(MaxDim)

    integer, allocatable, save:: iBlockCell_DI(:,:)
    real,    allocatable, save:: Dist_DI(:,:)

    integer:: iPoint, iBlock, iProcFound

    logical:: DoTest, DoTestMe
    character(len=*), parameter:: NameSub='IH_get_for_sc'
    !--------------------------------------------------------------------------
    call CON_set_do_test(NameSub, DoTest, DoTestMe)

    ! If nDim < MaxDim, make sure that all elements are initialized
    Dist_D = -1.0
    Xyz_D  =  0.0

    if(IsNew)then
       if(DoTest)write(iUnitOut,*) NameSub,': iProc, nPoint=', iProc, nPoint

       if(allocated(iBlockCell_DI)) deallocate(iBlockCell_DI, Dist_DI)
       allocate(iBlockCell_DI(0:nDim,nPoint), Dist_DI(nDim,nPoint))

       do iPoint = 1, nPoint

          Xyz_D(1:nDim) = Xyz_DI(:,iPoint)*Si2No_V(UnitX_)
          call find_grid_block(Xyz_D, iProcFound, iBlock, iCell_D, Dist_D, &
               UseGhostCell = .true.)

          if(iProcFound /= iProc)then
             write(*,*) NameSub,' ERROR: Xyz_D, iProcFound=', Xyz_D, iProcFound
             call IH_stop_mpi(NameSub//' could not find position on this proc')
          end if

          ! Store block and cell indexes and distances for interpolation
          iBlockCell_DI(0,iPoint)      = iBlock
          iBlockCell_DI(1:nDim,iPoint) = iCell_D(1:nDim)
          Dist_DI(:,iPoint)            = Dist_D(1:nDim)

       end do
    end if

    do iPoint = 1, nPoint

       Xyz_D(1:nDim) = Xyz_DI(:,iPoint)*Si2No_V(UnitX_)

       ! Use stored block and cell indexes and distances
       iBlock          = iBlockCell_DI(0,iPoint)
       iCell_D(1:nDim) = iBlockCell_DI(1:nDim,iPoint)
       Dist_D(1:nDim)  = Dist_DI(:,iPoint)

       State_V = interpolate_vector(State_VGB(:,:,:,:,iBlock), nVar, nDim, &
            MinIJK_D, MaxIJK_D, iCell_D=iCell_D, Dist_D=Dist_D)

       if(UseB0)then
          call get_b0(Xyz_D, B0_D)
          State_V(Bx_:Bz_) = State_V(Bx_:Bz_) + B0_D
       end if

       Data_VI(1:nVar,iPoint) = State_V*No2Si_V(iUnitCons_V)

    end do

  end subroutine IH_get_for_sc
  !============================================================================
  subroutine IH_get_ee_region(NameVar, nVarData, nPoint, Pos_DI, Data_VI, &
       iPoint_I)

    ! This routine is actually for EE-SC coupling

    ! This function will be called 3 times :
    !
    ! 1) Count grid cells to be overwritten by EE (except for extra variables)
    !
    ! 2) Return the Xyz_DGB coordinates of these cells
    !
    ! 3) Recieve Data_VI from SC and put them into State_VGB.
    !    The indexing array iPoint_I is needed to maintain the same order as
    !    the original position array Pos_DI was given in 2)

    use IH_BATL_lib,     ONLY: Xyz_DGB, nBlock, Unused_B, &
         IsRLonLat, nI, nJ, nK, CoordMin_DB, CellSize_DB
    use IH_ModGeometry,  ONLY: r_BLK
    use IH_ModPhysics,   ONLY: No2Si_V, UnitX_, Si2No_V, iUnitCons_V
    use IH_ModMain,      ONLY: UseB0
    use IH_ModB0,        ONLY: B0_DGB
    use IH_ModAdvance,   ONLY: State_VGB, Bx_, Bz_
    use IH_ModMultiFluid,ONLY: nIonFluid
    use IH_ModEnergy,    ONLY: calc_energy
    use CON_coupler,     ONLY: Grid_C, EE_, iVarTarget_V
    use ModNumConst,     ONLY: cPi, cTwoPi

    character(len=*), intent(inout):: NameVar ! List of variables
    integer,          intent(inout):: nVarData! Number of variables in Data_VI
    integer,          intent(inout):: nPoint  ! Number of points in Pos_DI
    real, intent(inout), allocatable, optional :: Pos_DI(:,:)  ! Positions

    real,    intent(in), optional:: Data_VI(:,:)    ! Recv data array
    integer, intent(in), optional:: iPoint_I(nPoint)! Order of data

    logical :: DoCountOnly
    integer :: i, j, k, iBlock, iPoint, iVarBuffer, iVar
    real    :: CoordMinEe_D(3), CoordMaxEe_D(3), Coord_D(3)

    character(len=*), parameter :: NameSub='IH_get_ee_region'
    !--------------------------------------------------------------------------
    if(.not.IsRLonLat) &
         call CON_stop(NameSub//' works for spherical grid only')

    DoCountOnly = nPoint < 1

    CoordMinEe_D(1) = Grid_C(EE_)%Coord1_I(1)
    CoordMinEe_D(2) = Grid_C(EE_)%Coord2_I(1)
    CoordMinEe_D(3) = Grid_C(EE_)%Coord3_I(1)
    CoordMaxEe_D(1) = Grid_C(EE_)%Coord1_I(2)
    CoordMaxEe_D(2) = Grid_C(EE_)%Coord2_I(2)
    CoordMaxEe_D(3) = Grid_C(EE_)%Coord3_I(2)

    ! Find ghost cells in the SC domain
    iPoint = 0
    do iBlock = 1, nBlock
       if(Unused_B(iBlock)) CYCLE
       do k = 1, nK; do j = 1, nJ; do i = 1, nI

          ! Set generalized coordinates (longitude and latitude)
          Coord_D = &
               CoordMin_DB(:,iBlock) + ((/i,j,k/)-0.5)*CellSize_DB(:,iBlock)

          ! Overwrite first coordinate with true radius
          Coord_D(1) = r_BLK(i,j,k,iBlock)

          ! Fix longitude if min longitude of EE is negative
          if(CoordMinEe_D(2) < 0.0 .and. Coord_D(2) > cPi) &
               Coord_D(2) = Coord_D(2) - cTwoPi

          ! Check if cell is inside EE domain
          if(any(Coord_D < CoordMinEe_D)) CYCLE
          if(any(Coord_D > CoordMaxEe_D)) CYCLE

          ! Found a point to be set by EE
          iPoint = iPoint + 1
          if(DoCountOnly) CYCLE

          if(present(Data_VI))then
             ! Put Data_VI obtained from EE into State_VGB
             ! Only a subset of variables are defined by EE
             do iVarBuffer = 1, nVarData
                iVar = iVarTarget_V(iVarBuffer)
                State_VGB(iVar,i,j,k,iBlock) = &
                     Data_VI(iVarBuffer,iPoint_I(iPoint)) &
                     *Si2No_V(iUnitCons_V(iVar))
             end do
             if(UseB0) State_VGB(Bx_:Bz_,i,j,k,iBlock) = &
                  State_VGB(Bx_:Bz_,i,j,k,iBlock) - B0_DGB(:,i,j,k,iBlock)
             call calc_energy(i,i,j,j,k,k,iBlock,1,nIonFluid)
          else
             ! Provide position to EE
             Pos_DI(:,iPoint) = Xyz_DGB(:,i,j,k,iBlock)*No2Si_V(UnitX_)
          end if

       end do; end do; end do
    end do

    if(DoCountOnly) nPoint = iPoint

  end subroutine IH_get_ee_region

  !===========================================================================
  subroutine IH_put_from_ee( &
       NameVar, nVarData, nPoint, Data_VI, iPoint_I, Pos_DI)

    ! This routine is actually for EE-SC coupling

    use IH_BATL_lib,    ONLY: nDim

    character(len=*), intent(inout):: NameVar ! List of variables
    integer,          intent(inout):: nVarData! Number of variables in Data_VI
    integer,          intent(inout):: nPoint  ! Number of points in Pos_DI

    real,    intent(in), optional:: Data_VI(:,:)    ! Recv data array
    integer, intent(in), optional:: iPoint_I(nPoint)! Order of data
    real, intent(out), allocatable, optional:: Pos_DI(:,:) ! Position vectors

    character(len=*), parameter :: NameSub='IH_put_from_ee'
    !--------------------------------------------------------------------------

    if(.not. present(Data_VI))then
       nPoint=0;
       ! get nPoint
       call IH_get_ee_region(NameVar, nVarData, nPoint, Pos_DI)

       if(allocated(Pos_DI)) deallocate(Pos_DI)
       allocate(Pos_DI(nDim,nPoint))

       ! get Pos_DI
       call IH_get_ee_region(NameVar, nVarData, nPoint, Pos_DI)

       RETURN
    end if

    ! set State variables
    call IH_get_ee_region(NameVar, nVarData, nPoint, Pos_DI, Data_VI, iPoint_I)

  end subroutine IH_put_from_ee

  !===========================================================================
  subroutine IH_get_for_ee(IsNew, NameVar, nVarIn, nDimIn, nPoint, Xyz_DI, &
       Data_VI)
    
    ! This routine is actually for SC-EE coupling

    ! Interpolate Data_VI from SC at the list of positions Xyz_DI 
    ! required by EE

    logical,          intent(in):: IsNew   ! true for new point array
    character(len=*), intent(in):: NameVar ! List of variables
    integer,          intent(in):: nVarIn  ! Number of variables in Data_VI
    integer,          intent(in):: nDimIn  ! Dimensionality of positions
    integer,          intent(in):: nPoint  ! Number of points in Xyz_DI

    real, intent(in) :: Xyz_DI(nDimIn,nPoint)  ! Position vectors
    real, intent(out):: Data_VI(nVarIn,nPoint) ! Data array

    ! Optimize search by storing indexes and distances
    integer, allocatable, save:: iBlockCell_DI(:,:)
    real,    allocatable, save:: Dist_DI(:,:)
    !-----------------------------------------------------------------------
    call IH_get_point_data(iBlockCell_DI, Dist_DI, IsNew, &
         NameVar, nVarIn, nDimIn, nPoint, Xyz_DI, Data_VI)

  end subroutine IH_get_for_ee
  !===========================
  integer function IH_n_particle(iBlockLocal)
    use IH_ModParticleFieldLine, ONLY: KindReg_
    use IH_BATL_lib, ONLY: Particle_I
    integer, intent(in) :: iBlockLocal
    !---------------------------------
    IH_n_particle = Particle_I(KindReg_)%nParticle
  end function IH_n_particle

end module IH_wrapper
