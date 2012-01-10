!^CFG COPYRIGHT UM
module CRASH_ModInterfaceNLTE
  use CRASH_ModMultiGroup, ONLY:nGroup
    use CRASH_M_EOS,   ONLY: UseNLTE=>UseCrashEos
  implicit none
contains
  subroutine read_nlte
    use ModReadParam,  ONLY: read_var
    !----------------------
    call read_var('UseNLTE',UseNLTE)
  end subroutine read_nlte
  !====================
  subroutine check_nlte
    use CRASH_M_EOS,   ONLY: SetOptions
    use CRASH_M_expTab,ONLY: exp_tab8
    use CRASH_ModMultiGroup, ONLY: EnergyGroup_I,set_multigroup
    use ModConst,            ONLY: cHPlanckEV
    use CRASH_M_NLTE,only : ng_rad
    use M_RADIOM, only : prep_projE, prepCorrUbar
    logical,save:: DoInit = .true.
    !---------------------
    if(.not.DoInit)return
    DoInit = .false.
    !Initialize NLTE calculations
    call exp_tab8()
    call setoptions(.false., .false., .true.)
    
    !What else?
    call set_multigroup(30,0.1/cHPlanckEV,20000.0/cHPlanckEV)
   
    !\
    ! Coefficients for transforming from the user defined grid to
    ! the refined logrithmic-uniform internal fixed grid
    !/ 
    call prep_projE(EnergyGroup_I(0:nGroup),nGroup)

    !\
    ! Initialize and calculate some internal arrays
    !/
    call prepCorrUbar()
   
    ng_rad=nGroup

  end subroutine check_nlte
  !==========================
  subroutine NLTE_EOS(& !Full list of the eos function parameters (no pIn)
       iMaterialIn,Rho,&
       TeIn, eTotalIn, eElectronIn,   &
       TeOut, eTotalOut, pTotalOut, GammaOut, CvTotalOut,    &
       eElectronOut, pElectronOut, GammaEOut, CvElectronOut, &
       OpacityPlanckOut_I, OpacityRosselandOut_I,            &
       HeatCond, TeTiRelax, Ne, zAverageOut, z2AverageOut)

    use CRASH_M_EOS,   ONLY: iMaterial, set_kbr
    use CRASH_M_NLTE,only : ng_rad,EoB, NLTE=>NLTE_EOS 
    use CRASH_ModEos,ONLY: eos, cAtomicMassCRASH_I, &
                           nZMix_II, cMix_II
    use CRASH_M_localProperties,only : atoNum,atoMass
    use ModConst, ONLY: cAtomicMass
    ! Eos function for single material

    integer, intent(in):: iMaterialIn     ! index of material
    real,    intent(in):: Rho             ! mass density [kg/m^3]
    !\
    !!   WARNING !!!
    !You cannot use total pressure and total energy density as input or output
    !parameters, if the electron temperature is not equal to ion temperature.
    !In this case ONLY electron energy density and electron pressure may be 
    !used.
    !/

    ! One of the following five energetic input parameters must be present
    real,    optional, intent(in)  :: TeIn         ! temperature SI[K]
    real,    optional, intent(in)  :: eTotalIn     ! internal energy density
    real,    optional, intent(in)  :: eElectronIn  ! internal energu density of electrons

    ! One or more of the output parameters can be present
    real,    optional, intent(out) :: TeOut        ! temperature
    real,    optional, intent(out) :: pTotalOut    ! pressure
    real,    optional, intent(out) :: eTotalOut    ! internal energy density
    real,    optional, intent(out) :: GammaOut     ! polytropic index
    real,    optional, intent(out) :: CvTotalOut   ! specific heat / unit volume
    ! Electrons !!!!!!   
    real,    optional, intent(out) :: pElectronOut ! pressure
    real,    optional, intent(out) :: eElectronOut ! internal energy density
    real,    optional, intent(out) :: GammaEOut    ! polytropic index
    real,    optional, intent(out) :: CvElectronOut! specific heat / unit volume
    real,    optional, intent(out) :: Ne           ! electron concentration [m-3]
    real,    optional, intent(out) :: zAverageOut  ! <z>
    real,    optional, intent(out) :: z2AverageOut ! <z^2>

    real,    optional, intent(out), &              ! Opacities
                 dimension(nGroup) :: OpacityPlanckOut_I, OpacityRosselandOut_I

    real,    optional, intent(out) :: HeatCond     ! electron heat conductivity (SI)
    real,    optional, intent(out) :: TeTiRelax    ! electron-ion interaction rate (SI)
    
    real:: Tz, NAtomic, Te
    !---------------
    !Set iMaterial and dependent variables

    iMaterial = iMaterialIn
    NAtomic = Rho/( cAtomicMassCRASH_I(iMaterial)*cAtomicMass )
    atomass = cAtomicMassCRASH_I(iMaterial)
    atonum  = sum(nZMix_II(:,iMaterial)*cMix_II(:,iMaterial))

    EoB(1:ng_rad)=0.0  !Zero radiation energy
    call set_kbr(NAtom=NAtomic)
    if(present(TeIn))then
       Te=TeIn
       !get Tz
       call NLTE(Natom=NAtomic,&
         Te_in=Te,             &
         Ee_in=EElectronIn,    &
         Et_in=ETotalIn,       &
         Zbar_out=zAverageOut, &
         Tz_out=Tz,            &
         Te_out=TeOut,         &
         Ee_out=EElectronOut,  &
         Et_out=ETotalOut,     &
         Pe_out=PElectronOut,  &
         Pt_out=PTotalOut)
    else
       call NLTE(Natom=NAtomic,&
         Ee_in=EElectronIn,   &
         Et_in=ETotalIn,      &
         Zbar_out=zAverageOut,&
         Tz_out=Tz,           &
         Te_out=Te,           &
         Ee_out=EElectronOut, &
         Et_out=ETotalOut,    &
         Pe_out=PElectronOut, &
         Pt_out=PTotalOut)
       if(present(TeOut))TeOut=Te
    end if
    if(&
         present(GammaOut).or.      &
         present(GammaEOut).or.     &
         present(CvTotalOut).or.    &
         present(CvElectronOut).or. &
         present(OpacityPlanckOut_I).or. &
         present(OpacityRosselandOut_I).or. &
         present(HeatCond).or.      &
         present(TeTiRelax).or.     &
         present(Ne).or.            &
         present(zAverageOut).or.   & 
         present(z2AverageOut) )    &
         call eos(&
         iMaterial=iMaterialIn,       &
         Rho=Rho,                     &
         TeIn=Tz,                     &
         GammaOut=GammaOut,           &
         CvTotalOut=CvTotalOut,       &
         GammaEOut=GammaEOut,         &
         CvElectronOut=CvElectronOut, &
         OpacityPlanckOut_I=OpacityPlanckOut_I,       &
         OpacityRosselandOut_I=OpacityRosselandOut_I, &
         HeatCond=HeatCond,           &
         TeTiRelax=TeTiRelax,         &
         Ne=Ne,                       &
         zAverageOut=zAverageOut,   &
         z2AverageOut=z2AverageOut)
  end subroutine NLTE_EOS
end module CRASH_ModInterfaceNLTE
