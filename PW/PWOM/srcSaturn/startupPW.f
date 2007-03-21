 
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C     ALEX(10/11/04): I THINK THAT THIS SUBROUTINE INITIALIZES THE GRID AND
C     AND SETS CONSTANTS. IT MUST BE INITIALIZED EVERY TIME THE CODE RUNS
C     EVEN IF RESTARTING FROM A FILE.
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

      SUBROUTINE STRT
C
C
      use ModCommonVariables

C
      NPT1=14
      NPT2=16
      NPT3=30
      NPT4=35
      NPT5=60
      NPT6=70
1     FORMAT(5X,I5)
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     DEFINE THE GAS SPECIFIC HEAT AT CONSTANT PRESSURE (CP),          C
C           THE AVERAGE MOLECULAR MASS (AVMASS), THE ACTUAL            C
C           GAS CONSTANT (RGAS) AND THE SPECIFIC HEAT RATIO (GAMMA)    C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C

CALEX not I use O for H3 and he for H2
C Gas constant = k_Boltzmann/AMU
      RGAS=8.314E7
C Adiabatic index
      GAMMA=5./3.
C AMU in gramms
      XAMU=1.6606655E-24
C Mass of atomic H3 in gramms
      XMSO=3.0237*XAMU
C Mass of atomic H in gramms
      XMSH=1.00797*XAMU
C Mass of atomic He in gramms
      XMSHE=2.*XAMU
C Mass of electron in gramms
      XMSE=9.109534E-28
C Relative mass of H3 to electron
      RTOXEL=XMSE/XMSO
C Relative mass of atomic H to electron
      RTHDEL=XMSE/XMSH
C Relative mass of H2 to electron
      RTHEEL=XMSE/XMSHE
C kB/m_H3
      RGASO=RGAS*XAMU/XMSO
C kB/m_H
      RGASH=RGAS*XAMU/XMSH
C kB/m_H2
      RGASHE=RGAS*XAMU/XMSHE
C kB/m_e
      RGASE=RGAS*XAMU/XMSE
      GMIN1=GAMMA-1.
      GMIN2=GMIN1/2.
      GPL1=GAMMA+1.
      GPL2=GPL1/2.
      GM12=GMIN1/GAMMA/2.
      GRAR=GAMMA/GMIN2
      GREC=1./GAMMA
      CPO=GAMMA*RGASO/GMIN1
      CPH=GAMMA*RGASH/GMIN1
      CPHE=GAMMA*RGASHE/GMIN1
      CPE=GAMMA*RGASE/GMIN1
      CVO=RGASO/GMIN1
      CVH=RGASH/GMIN1
      CVHE=RGASHE/GMIN1
      CVE=RGASE/GMIN1

CALEX Set the planet radius and surface gravity, rotation freq
      RE=60268.E5
      GSURF=980.*.916
c      Omega=1./37800.

      Omega=0.
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     DEFINE THE RADIAL GRID STRUCTURE                                 C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C      READ (5,2) DRBND
CALEX DRBND=altitude step? I think the units here are in cm not meters
CALEX like most of the code.
c      DRBND=4.E6
c      DrBnd=3.0e7
c      DrBnd=1.5e7
      DrBnd=0.75e7

      
CALEX RN=lower boundary of the simulation? 
CALEX RAD=radial distance of cell centers?      
CALEX RBOUND=radial distance of lower boundary of cell     
CALEX ALTD = same as RAD but distance is from surface, not center of planet
      RN=1.40E8+RE+0.5*DRBND

c      RN=1.00E8+RE+0.5*DRBND


      DO 20 KSTEP=1,NDIM1
         RBOUND(KSTEP)=RN+(KSTEP-1)*DRBND
20    CONTINUE
      DO 30 KSTEP=1,NDIM
         KSTEP1=KSTEP+1
         RAD(KSTEP)=(RBOUND(KSTEP)+RBOUND(KSTEP1))/2.
         ALTD(KSTEP)=RAD(KSTEP)-RE
 30   CONTINUE
      ALTMIN=ALTD(1)-DRBND
      ALTMAX=ALTD(NDIM)+DRBND
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     READ THE EXPONENT OF THE  A(R)=R**NEXP  AREA FUNCTION            C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C      READ (5,1) NEXP
      NEXP=3
      
CAlex      write(*,*) NEXP

CALEX AR stands for area function. 12 is the lower boundary of the cell
CALEX and 23 is the upper boundary

      DO 40 K=1,NDIM
      DAREA(K)=NEXP/RAD(K)
      AR12(K)=(RBOUND(K)/RAD(K))**NEXP
      AR23(K)=(RBOUND(K+1)/RAD(K))**NEXP
!     For the cell volume in the Rusanov Solver we use a cell volume 
!     calculated by assuming an area function in the form A=alpha r^3
!     and then assuming each cell is a truncated cone.
!     So CellVolume_C is the volume of cell j divided by the crossesction
!     of cell j, A(j). 

      CellVolume_C(K)=1.0/3.0 * DrBnd *
     &     ( Ar12(K) + Ar23(K) + ( Ar12(K)*Ar23(K) )**0.5 ) 

40    CONTINUE

! area and volume for ghost cell
      AR12top(1)=((RN+nDim*drbnd)/(RN+nDim*drbnd+drbnd*0.5))**NEXP
      AR23top(1)=((RN+(nDim+1.0)*drbnd)/(RN+(nDim+1.0)*drbnd+drbnd*0.5))**NEXP
      CellVolumeTop(1)=1.0/3.0 * DrBnd *
     &     ( Ar12top(1) + Ar23top(1) + ( Ar12top(1)*Ar23top(1) )**0.5 ) 


      AR12top(2)=((RN+(nDim+1.0)*drbnd)/(RN+(nDim+1.0)*drbnd+drbnd*0.5))**NEXP
      AR23top(2)=((RN+(nDim+2.0)*drbnd)/(RN+(nDim+2.0)*drbnd+drbnd*0.5))**NEXP
      CellVolumeTop(2)=1.0/3.0 * DrBnd *
     &     ( Ar12top(2) + Ar23top(2) + ( Ar12top(2)*Ar23top(2) )**0.5 ) 
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     READ FIELD ALIGNED CURRENT DENSITY AT LOWEST GRID POINT          C
C        (UNIT=AMPERE/M**2)                                            C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C      READ (5,2) CURR(1)

      
      CURR(1)=2.998E2*CURR(1)
!      CURTIM=150.
!      CURTIM0=500.
      CURRMN=CURR(1)*(RAD(1)/(RAD(1)-DRBND))**NEXP
      CURRMX=CURR(1)*(RAD(1)/(RAD(NDIM)+DRBND))**NEXP
      
      do k=2,nDim
         CURR(k)=CURR(1)*(RAD(1)/(RAD(k)))**NEXP
      enddo



C      SGN1=1.
C      IF (CURR(1).LT.0.) SGN1=-1.
C      IF (ABS(CURR(1)).LT.1.E-4) SGN1=0.
C      CURRMX=SGN1*0.2998*(RAD(1)/(RAD(NDIM)+DRBND))**NEXP
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     DEFINE THE NEUTRAL ATMOSPHERE MODEL                              C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C IF GEOMAGNETIC COORDINATES ARE SPECIFIED, SET IART TO 1 !!!!!
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     DEFINE DATE                                                      C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C SOLAR MAXIMUM WINTER
C      IYD=80360
C      F107A=180.
C      F107=180.
C SOLAR MAXIMUM SUMMER
C      IYD=80172
C      F107A=180.
C      F107=180.
C SOLAR MINIMUM WINTER
C      IYD=84360
C      F107A=60.
C      F107=60.
C SOLAR MINIMUM SUMMER
C     IYD=84172
C     F107A=60.
C     F107=60.
C      SEC=43200.
C      STL=12.
C      GMLAT=80.
C      GMLONG=0.
C      IART=1
      GLAT=80.
C      GLONG=0.
C      IART=0
C FEB 20, 1990
CALEX IYD=year_day of year

c      IYD=90051
c      SEC=20.75*3600.
c      F107A=180.
c      F107=189.5
c      IART=0
c      GLONG=325.13
c      GLAT=70.47
C END
CALEX GGM determines geomagnetic lat. from geographic lat and lon
CALEX since the dipole on Saturn is aligned with the rotation axis
CALEX I have set GMLONG=GLONG
CALEX      CALL GGM(IART,GLONG,GLAT,GMLONG,GMLAT)
!      GMLONG=GLONG
!      GMLAT=GLAT

      DO 49 I=1,7
      AP(I)=50.
49    CONTINUE 
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC 
C                                                                      C
      DO 50 K=1,NDIM
         CALL MODATM(ALTD(K),XH2(K),XH(K),XH2O(K),XCH4(K),XTN(K))
50    CONTINUE


CALEX I am not calling glowex now but in the future 
CALEX we might need to use this for radiative transfer etc      
CALEX      CALL GLOWEX
CALEX      DO 1099 J = 1,40
CALEX         WRITE (iUnitOutput,9999) ALTD(J),PHOTOTF(J+1) 
CALEX 9999    FORMAT(2X,1PE15.3,2X,1PE15.3)
CALEX 1099 CONTINUE
C
      CALL STRT1
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     DEFINE TOPSIDE ELECTRON HEAT FLUX AND PARAMETRIC HEAT SOURCES    C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C      READ (5,2) ETOP,ELFXIN

CALEX I don't know how to fix this heat input for Saturn.
CALEX In Dee's thesis she says you need electon heat flux to be a minimum
CALEX of 20E-3 ergs cm^2 /s.      
C      ETOP=1.0E-3
      ETOP=20.0E-3
c      ETOP=25.0E-3
      ELFXIN=0.
C
C      ELFXIN=9.
C
2     FORMAT(6X,1PE15.4)
     
C      READ (5,2) HEATI1,HEATI2,ELHEAT
      HEATI1=0.
      HEATI2=0.
C
      HEATI1=1.0E-7
calex origionally heatI1 was 0 and heat I2 was not 0, but i have a suspicion that
Calex this should not be true. I think the two refers to helium which we are not 
calex looking at.
c      HEATI2=2.5E-11
C
      ELHEAT=0.
      
      HEATA1=3.5E7
      HEATA2=2.0E8
      HEATA3=1.5E8
      HEATS1=2.*1.0E7**2
      HEATS2=2.*2.5E7**2
      HEATS3=2.*1.0E7**2
      DO 53 K=1,NDIM
      HEATX1=EXP(-(ALTD(K)-HEATA1)**2/HEATS1)
      HEATX2=EXP(-(ALTD(K)-HEATA2)**2/HEATS2)
      HEATX3=EXP(-(ALTD(K)-HEATA3)**2/HEATS3)
      QOXYG(K)=(HEATI1*HEATX1+HEATI2*HEATX2)/
     #         (DOXYG(K)+DHYD(K)+DHEL(K))
calex origionally it was qhyd=qoxy/16 but I think 16 should be 3 since
calex I am letting oxy stand in for H3+
      QHYD(K)=QOXYG(K)/3.
      QHEL(K)=QOXYG(K)/4.
C
      QOXYG(K)=0.
C
      QOXYG(K)=0.
      QHYD(K)=0.
      QHEL(K)=0.

      QELECT(K)=ELHEAT*HEATX3
53    CONTINUE
      DO 54 K=1,NDIM,10
      
52    FORMAT(5(1PE15.4))
54    CONTINUE
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     READ STARTING TIME, TERMINATION TIME AND BASIC TIME STEP         C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C      READ (5,4) TIME,TMAX
CCC      TIME=0.
CCC      TMAX=1.E6
      
      
4     FORMAT(6X,2(1PE15.4))
C      READ (5,2) DT   1/20.0 is a good value
C     Read in the time step
      write(*,*) dt
c      DT=1./1.
      DTX1=DT
      DTR1=DTX1/DRBND
      DTX2=DT*NTS
      DTR2=DTX2/DRBND
    
      H0=0.5/DRBND
      H1E1=1./DTX1
      H1O1=1./DTX1
      H1H1=1./DTX1
      H1E2=1./DTX2
      H1O2=1./DTX2
      H1H2=1./DTX2
      H2=1./DRBND/DRBND
      H3=0.5*H2
      H4=0.5*H0
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     DEFINE THE HEAT CONDUCTION PARAMETERS                            C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
CALEX terms with "surf" in them refer to surface values      
      HLPE0=GMIN1/RGASE
      HLPE=1.23E-6*GMIN1/RGASE
      HLPO=2.86E-8*(XMSE/XMSO)*GMIN1/RGASO
      HLPHE=0.
c2.5*GMIN1/RGASHE
      HLPH=7.37E-8*(XMSE/XMSH)*GMIN1/RGASH

 
      
CALEX These are the heat conductivities at the lower boundary. Note:
CALEX that no allowance is made to take into account the effect of
CALEX neutrals on the heat conduction as was done at earth.     
      TCSFO=HLPO*(DSURFO/DSURFE)*TSURFO**2.5
      TCSFE=HLPE*TSURFE**2.5
      TCSFH=HLPH*(DSURFH/DSURFE)*TSURFH**2.5
      TCSFHE=HLPHE*TSURHE
      
C!      TCSFO=HLPO*TSURFO**2.5
C!      TCSFE=HLPE*TSURFE**2.5
C!      TCSFH=HLPH*TSURFH**2.5
C!      TCSFHE=HLPHE*TSURHE**2.5
      CALL MODATM(ALTMAX,XNH2,XNH,XNH2O,XNCH4,TEMP)
      XTNMAX=TEMP

      ETOP=ETOP*DRBND/1.23E-6
      CALL NEWBGD
3     FORMAT(4X,I6)
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     PRINT INITIAL AND BOUNDARY PARAMETERS                            C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C      READ(5,3) NCNPRT
      NCNPRT=0
      
      CALL MODATM(ALTMIN,XNH2,XNH,XNH2O,XNCH4,XNT)
      CALL MODATM(ALTMAX,YNH2,YNH,YNH2O,YNCH4,YNT)
      DO 60 I=1,NDIM
      ALTD(I)=ALTD(I)/1.E5
60    CONTINUE
      ALTMIN=ALTMIN/1.E5
      ALTMAX=ALTMAX/1.E5
      ETOP1=ETOP*1.23E-6/DRBND
      CALL COLLIS(NDIM)
      CALL ELFLDW

      if (DoLog) then

      IF (NCNPRT.NE.0) GO TO 999
      
      WRITE(iUnitOutput,1005) NDIM
1005  FORMAT(1H1,5X,'NUMBER OF CELLS=',I4)
      WRITE(iUnitOutput,1020) NEXP
1020  FORMAT(5X,'NEXP=',I1)
      WRITE (iUnitOutput,1008) GAMMA,RGASO,CPO,CVO,RGASHE,CPHE,CVHE,
     ;RGASH,CPH,CVH,RGASE,CPE,CVE
1008  FORMAT(5X,'GAMMA=',F4.2,/5X,'RGAS(OXYGEN)=',1PE10.4,7X,
     ;'CP(OXYGEN)=',1PE10.4,7X,'CV(OXYGEN)=',1PE10.4
     ;/5X,'RGAS(HELIUM)=',1PE10.4,7X,
     ;'CP(HELIUM)=',1PE10.4,7X,'CV(HELIUM)=',1PE10.4/5X,
     ;'RGAS(HYDROGEN)=',1PE10.4,5X,'CP(HYDROGEN)=',1PE10.4,5X,
     ;'CV(HYDROGEN)=',1PE10.4,/5X,'RGAS(ELECTRON)=',1PE10.4,5X
     ;,'CP(ELECTRON)=',1PE10.4,5X,'CV(ELECTRON)=',1PE10.4)
      WRITE (iUnitOutput,1023)
1023  FORMAT(1H0,5X,'LOWER BOUNDARY PLASMA PARAMETERS:')
      WRITE(iUnitOutput,1001)
1001  FORMAT(1H ,4X,'OXYGEN:')
      WRITE (iUnitOutput,1009) USURFO,PSURFO,DSURFO,TSURFO,WSURFO
1009  FORMAT(5X,'VELOCITY=',1PE11.4,3X,'PRESSURE=',1PE10.4,3X,
     ;'MASS DENSITY=',1PE10.4,3X,'TEMPERATURE=',1PE10.4,3X,
     ;'SOUND VELOCITY=',1PE10.4)
      WRITE(iUnitOutput,10021)
10021 FORMAT(1H ,4X,'HELIUM:')
      WRITE (iUnitOutput,1009) USURHE,PSURHE,DSURHE,TSURHE,WSURHE
      WRITE(iUnitOutput,1002)
1002  FORMAT(1H ,4X,'HYDROGEN:')
      WRITE (iUnitOutput,1009) USURFH,PSURFH,DSURFH,TSURFH,WSURFH
      WRITE(iUnitOutput,1003)
1003  FORMAT(1H ,4X,'ELECTRONS:')
      WRITE (iUnitOutput,1009) USURFE,PSURFE,DSURFE,TSURFE,WSURFE
      WRITE (iUnitOutput,1027)
1027  FORMAT(1H0,5X,'UPPER BOUNDARY INITIAL PLASMA PARAMETERS:')
      WRITE (iUnitOutput,1004)
1004  FORMAT(1H ,4X,'OXYGEN:')
      WRITE (iUnitOutput,1009) UBGNDO,PBGNDO,DBGNDO,TBGNDO,WBGNDO
      WRITE (iUnitOutput,1088)
1088  FORMAT(1H ,4X,'HELIUM:')
      WRITE (iUnitOutput,1009) UBGNHE,PBGNHE,DBGNHE,TBGNHE,WBGNHE
      WRITE (iUnitOutput,1006)
1006  FORMAT(1H ,4X,'HYDROGEN:')
      WRITE (iUnitOutput,1009) UBGNDH,PBGNDH,DBGNDH,TBGNDH,WBGNDH
      WRITE(iUnitOutput,1007)
1007  FORMAT(1H ,4X,'ELECTRONS:')
      WRITE (iUnitOutput,1009) UBGNDE,PBGNDE,DBGNDE,TBGNDE,WBGNDE
      WRITE (iUnitOutput,1029) ETOP1
1029  FORMAT(1H0,5X,'TOPSIDE ELECTRON HEATING RATE:',1PE10.4,
     ;' ERGS/CM**3/SEC')

      write(iUnitOutput,*) 'CMH3pH,CMH3pH2,CMH3pHp,CMH3pEL'
      write(iUnitOutput,*) CMH3pH,CMH3pH2,CMH3pHp,CMH3pEL
     
      write(iUnitOutput,*) 'CMHpH,CMHpH2,CMHpH3p,CMHpEL'
      write(iUnitOutput,*) CMHpH,CMHpH2,CMHpH3p,CMHpEL
      
      write(iUnitOutput,*) 'CMELH,CMELH2,CMELHp,CMELH3p'
      write(iUnitOutput,*) CMELH,CMELH2,CMELHp,CMELH3p

      WRITE (iUnitOutput,1050) 
1050  FORMAT(1H0,5X,'ENERGY COLLISION TERM COEFFICIENTS')
      WRITE (iUnitOutput,1051)CTHpH,CTHpH2,CTHpH3p,CTHpEL,CTH3pH,CTH3pH2,CTH3pHp,
     $ CTH3pEL,CTELH,CTELH2,CTELHp,CTELH3p

1051  FORMAT(1H0,5X,'CTHpH=',1PE10.4,5X,'CTHpH2=',1PE10.4,4X,
     $'CTHpH3p=',1PE10.4/5X,'CTHpEL=',1PE10.4,5X,'CTH3pH=',1PE10.4,5X,
     $'CTH3pH2=',1PE10.4,5X,'CTH3pHp=',1PE10.4,5X,'CTH3pEL=',1PE10.4/
     $5X,'CTELH=',1PE10.4,5X,'CTELH2=',1PE10.4,4X,
     $'CTELHp=',1PE10.4/5X,'CTELH3p=',1PE10.4,5X)

      WRITE (iUnitOutput,1052) CMHpH,CMHpH2,CMHpH3p,CMHpEL,CMH3pH,CMH3pH2,CMH3pHp,
     $ CMH3pEL,CMELH,CMELH2,CMELHp,CMELH3p

1052  FORMAT(1H0,5X,'CMHpH=',1PE10.4,5X,'CMHpH2=',1PE10.4,4X,
     $'CMHpH3p=',1PE10.4/5X,'CMHpEL=',1PE10.4,5X,'CMH3pH=',1PE10.4,5X,
     $'CMH3pH2=',1PE10.4,5X,'CMH3pHp=',1PE10.4,5X,'CMH3pEL=',1PE10.4/
     $5X,'CMELH=',1PE10.4,5X,'CMELH2=',1PE10.4,4X,
     $'CMELHp=',1PE10.4/5X,'CMELH3p=',1PE10.4,5X)

      WRITE (iUnitOutput,1053)

1053  FORMAT(1H0,5X,'HEAT CONDUCTION COEFFICIENTS AT UPPER BOUNDARY')

C!      WRITE (iUnitOutput,1054) CZHN2,CZHO2,CZHO,CZHOX,CZHEN2,CZHEO2,CZHEHE,
C!     $CZHEO,CZHEH,CZHEOX,CZHEHD,XTNMAX
C!1054  FORMAT(1H0,5X,'CZHN2=',1PE10.4,6X,'CZHO2=',1PE10.4,6X,
C!     $'CZHO=',1PE10.4,7X,'CZHOX=',1PE10.4/5X,'CZHEN2=',1PE10.4,5X,
C!     $'CZHEO2=',1PE10.4,5X,'CZHEHE=',1PE10.4,5X,'CZHEO=',1PE10.4/
C!     $5X,'CZHEH=',1PE10.4,6X,'CZHEOX=',1PE10.4,5X,'CZHEHD=',
C!     $1PE10.4/5X,'XTNMAX=',1PE10.4)

      WRITE (iUnitOutput,1012)

1012  FORMAT(1H1,45X,'NEUTRAL ATMOSPHERE NUMBER DENSITIES')

      WRITE(iUnitOutput,1014)

1014  FORMAT(16X,'ALT',13X,'H2',13X,'H',15X,'H2O',14X,'CH4',
     $     15X,'T')

      K=0

      WRITE (iUnitOutput,1022) K, ALTMIN,XNH2,XNH,XNH2O,XNCH4,XNT

      NDMQ=NPT1

      IF (NDIM.LT.NPT2) NDMQ=NDIM

      do K=1,NDMQ
         WRITE(iUnitOutput,1022) K,ALTD(K),XH2(K),XH(K),XH2O(K),XCH4(K),
     $        XTN(K)
      enddo


      IF (NDIM.LT.NPT2) GO TO 290

      NDMQ=NPT3

      IF (NDIM.LT.NPT4) NDMQ=NDIM
      
      do K=NPT2,NDMQ,2
         WRITE(iUnitOutput,1022) K,ALTD(K),XH2(K),XH(K),XH2O(K),XCH4(K),
     $        XTN(K)
      enddo

      IF (NDIM.LT.NPT4) GO TO 290
      NDMQ=NPT5
      
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      
      do K=NPT4,NDMQ,5
         WRITE(iUnitOutput,1022) K,ALTD(K),XH2(K),XH(K),XH2O(K),XCH4(K),
     $        XTN(K)
      enddo
      IF (NDIM.LT.NPT6) GO TO 290
      do K=NPT6,NDIM,10
         WRITE(iUnitOutput,1022) K,ALTD(K),XH2(K),XH(K),XH2O(K),XCH4(K),
     $        XTN(K)
      enddo
 290  CONTINUE
      
      K=NDIM+1
      
      WRITE (iUnitOutput,1022) K, ALTMAX,YNH2,YNH,YNH2O,YNCH4,YNT
      
      WRITE(iUnitOutput,1015)
c
calex Now output the source coef.

1015  FORMAT(1H1,55X,'SOURCE COEFFICIENTS:')
      WRITE (iUnitOutput,1016)


1016  FORMAT(12X,'ALT',6X,'GRAVTY',6X,'Centrifugal',5X,'FFHpp1',5X,
     ;'FFHpp3',5X,
     ;'FFHpp4',5X,'FFHpc2',5X,'FFHpc3',5X,'FFHpc8',4X,'FFHpr1',
     ;4X,'FFH3pc1',5X,'FFH3pc2',5X,'FFH3pc6',5X,'FFH3pc7',
     ;5X,'FFH3pr2')

      NDMQ=NPT1

      IF (NDIM.LT.NPT2) NDMQ=NDIM

      DO  K=1,NDMQ
         WRITE(iUnitOutput,1019) K,ALTD(K),GRAVTY(K),Centrifugal(K),FFHpp1(K),FFHpp3(K),
     $        FFHpp4(K),FFHpc2(K),FFHpc3(K),FFHpc8(K),FFHpr1(K),FFH3pc1(K),
     $        FFH3pc2(K), FFH3pc6(K),FFH3pc7(K),FFH3pr2(K)
      enddo


      IF (NDIM.LT.NPT2) GO TO 295
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM

      do K=NPT2,NDMQ,2
      WRITE(iUnitOutput,1019) K,ALTD(K),GRAVTY(K),FFHpp1(K),FFHpp3(K),
     $        FFHpp4(K),FFHpc2(K),FFHpc3(K),FFHpc8(K),FFHpr1(K),FFH3pc1(K),
     $        FFH3pc2(K), FFH3pc6(K),FFH3pc7(K),FFH3pr2(K)

      enddo

      IF (NDIM.LT.NPT4) GO TO 295
      NDMQ=NPT5

      IF (NDIM.LT.NPT6) NDMQ=NDIM

      do K=NPT4,NDMQ,5
         WRITE(iUnitOutput,1019) K,ALTD(K),GRAVTY(K),FFHpp1(K),FFHpp3(K),
     $        FFHpp4(K),FFHpc2(K),FFHpc3(K),FFHpc8(K),FFHpr1(K),FFH3pc1(K),
     $        FFH3pc2(K), FFH3pc6(K),FFH3pc7(K),FFH3pr2(K)

      enddo

      IF (NDIM.LT.NPT6) GO TO 295

      do K=NPT6,NDIM,10
         WRITE(iUnitOutput,1019) K,ALTD(K),GRAVTY(K),FFHpp1(K),FFHpp3(K),
     $        FFHpp4(K),FFHpc2(K),FFHpc3(K),FFHpc8(K),FFHpr1(K),FFH3pc1(K),
     $        FFH3pc2(K), FFH3pc6(K),FFH3pc7(K),FFH3pr2(K)

      enddo
295   CONTINUE

      WRITE(iUnitOutput,1017)
1017  FORMAT(1H1,50X,'COLLISION COEFFICIENTS FOR H3p')

C!      WRITE(iUnitOutput,1018)
C!1018  FORMAT(12X,'ALT',7X,'CLOXN2',6X,'CLOXO2',6X,'CLOXO',7X,
C!     ;'CLOXHE',6X,'CLOXH',7X,'CLOXHL',6X,'CLOXHD',6X,'CLOXEL')
C!      NDMQ=NPT1
C!      IF (NDIM.LT.NPT2) NDMQ=NDIM
C!      DO 530 K=1,NDMQ
C!      WRITE (iUnitOutput,1180) K,ALTD(K),CLOXN2(K),CLOXO2(K),CLOXO(K),
C!     $CLOXHE(K),CLOXH(K),CLOXHL(K),CLOXHD(K),CLOXEL(K)
C!530   CONTINUE
C!      IF (NDIM.LT.NPT2) GO TO 590
C!      NDMQ=NPT3
C!      IF (NDIM.LT.NPT4) NDMQ=NDIM
C!      DO 540 K=NPT2,NDMQ,2
C!      WRITE (iUnitOutput,1180) K,ALTD(K),CLOXN2(K),CLOXO2(K),CLOXO(K),
C!     $CLOXHE(K),CLOXH(K),CLOXHL(K),CLOXHD(K),CLOXEL(K)
C!540   CONTINUE
C!      IF (NDIM.LT.NPT4) GO TO 590
C!      NDMQ=NPT5
C!      IF (NDIM.LT.NPT6) NDMQ=NDIM
C!      DO 550 K=NPT4,NDMQ,5
C!      WRITE (iUnitOutput,1180) K,ALTD(K),CLOXN2(K),CLOXO2(K),CLOXO(K),
C!     $CLOXHE(K),CLOXH(K),CLOXHL(K),CLOXHD(K),CLOXEL(K)
C!550   CONTINUE
C!      IF (NDIM.LT.NPT6) GO TO 590
C!      DO 560 K=NPT6,NDIM,10
C!      WRITE (iUnitOutput,1180) K,ALTD(K),CLOXN2(K),CLOXO2(K),CLOXO(K),
C!     $CLOXHE(K),CLOXH(K),CLOXHL(K),CLOXHD(K),CLOXEL(K)
C!560   CONTINUE
C!590   CONTINUE

C!1      WRITE (iUnitOutput,1217)
C!11217  FORMAT(1H1,50X,'COLLISION COEFFICIENTS FOR HELIUM')
C!1      WRITE(iUnitOutput,1218)
C!11218  FORMAT(12X,'ALT',7X,'CLHEN2',6X,'CLHEO2',6X,'CLHEO',7X,
C!1     ;'CLHEHE',6X,'CLHEH',7X,'CLHEOX',6X,'CLHEHD',6X,'CLHEEL')
C!1      NDMQ=NPT1
C!1      IF (NDIM.LT.NPT2) NDMQ=NDIM
C!1      DO 1230 K=1,NDMQ
C!1      WRITE (iUnitOutput,1180) K,ALTD(K),CLHEN2(K),CLHEO2(K),CLHEO(K),
C!1     $CLHEHE(K),CLHEH(K),CLHEOX(K),CLHEHD(K),CLHEEL(K)
C!11230  CONTINUE
C!1      IF (NDIM.LT.NPT2) GO TO 1290
C!1      NDMQ=NPT3
C!1      IF (NDIM.LT.NPT4) NDMQ=NDIM
C!1      DO 1240 K=NPT2,NDMQ,2
C!1      WRITE (iUnitOutput,1180) K,ALTD(K),CLHEN2(K),CLHEO2(K),CLHEO(K),
C!1     $CLHEHE(K),CLHEH(K),CLHEOX(K),CLHEHD(K),CLHEEL(K)
C!11240  CONTINUE
C!1      IF (NDIM.LT.NPT4) GO TO 1290
C!1      NDMQ=NPT5
C!1      IF (NDIM.LT.NPT6) NDMQ=NDIM
C!1      DO 1250 K=NPT4,NDMQ,5
C!1      WRITE (iUnitOutput,1180) K,ALTD(K),CLHEN2(K),CLHEO2(K),CLHEO(K),
C!1     $CLHEHE(K),CLHEH(K),CLHEOX(K),CLHEHD(K),CLHEEL(K)
C!11250  CONTINUE
C!1      IF (NDIM.LT.NPT6) GO TO 1290
C!1      DO 1260 K=NPT6,NDIM,10
C!1      WRITE (iUnitOutput,1180) K,ALTD(K),CLHEN2(K),CLHEO2(K),CLHEO(K),
C!1     $CLHEHE(K),CLHEH(K),CLHEOX(K),CLHEHD(K),CLHEEL(K)
C!11260  CONTINUE
C!11290  CONTINUE
C!1      WRITE (iUnitOutput,2217)

2217  FORMAT(1H1,50X,'COLLISION COEFFICIENTS FOR HYDROGEN')
      WRITE(iUnitOutput,2218)
2218  FORMAT(12X,'ALT',7X,'CLHpH3p',7X,'CLHpH')
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      do K=1,NDMQ
         WRITE (iUnitOutput,1180) K,ALTD(K),CLHpH3p(K),CLHpH(K)
      enddo
      
      IF (NDIM.LT.NPT2) GO TO 2290
      NDMQ=NPT3
      
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      
      do K=NPT2,NDMQ,2
         WRITE (iUnitOutput,1180) K,ALTD(K),CLHpH3p(K),CLHpH(K)
      enddo
      
      IF (NDIM.LT.NPT4) GO TO 2290
      NDMQ=NPT5
      
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      
      do  K=NPT4,NDMQ,5
         WRITE (iUnitOutput,1180) K,ALTD(K),CLHpH3p(K),CLHpH(K)
      enddo
      
      IF (NDIM.LT.NPT6) GO TO 2290
      
      do K=NPT6,NDIM,10
         WRITE (iUnitOutput,1180) K,ALTD(K),CLHpH3p(K),CLHpH(K)
      enddo
2290  CONTINUE

      WRITE (iUnitOutput,3217)
3217  FORMAT(1H1,50X,'COLLISION COEFFICIENTS FOR ELECTRONS')
      WRITE(iUnitOutput,3218)
3218  FORMAT(12X,'ALT',6X,'CLELHp',6X,'CLELH3p',6X,'CLELH')
      
      NDMQ=NPT1
      
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      
      do K=1,NDMQ
         WRITE (iUnitOutput,1180) K,ALTD(K),CLELHp(K),CLELH3p(K),CLELH(K)
      enddo
      
      IF (NDIM.LT.NPT2) GO TO 3290
      
      NDMQ=NPT3
      
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      
      do K=NPT2,NDMQ,2
         WRITE (iUnitOutput,1180) K,ALTD(K),CLELHp(K),CLELH3p(K),CLELH(K)
      enddo
      
      IF (NDIM.LT.NPT4) GO TO 3290
      
      NDMQ=NPT5
      
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      
      do K=NPT4,NDMQ,5
         WRITE (iUnitOutput,1180) K,ALTD(K),CLELHp(K),CLELH3p(K),CLELH(K)
      enddo

      IF (NDIM.LT.NPT6) GO TO 3290

      do K=NPT6,NDIM,10
         WRITE (iUnitOutput,1180) K,ALTD(K),CLELHp(K),CLELH3p(K),CLELH(K)
      enddo
3290  CONTINUE


      WRITE(iUnitOutput,1047)
1047  FORMAT(1H1,50X,'COLLISION FREQUENCIES FOR H3')
C!      WRITE(iUnitOutput,1048)
C!1048  FORMAT(12X,'ALT',7X,'CFH3pHp',6X,'CFH3pEL',6X,'CFH3pH',7X,
C!     ;'CFH3pH2')
C!
C!      NDMQ=NPT1
C!
C!      IF (NDIM.LT.NPT2) NDMQ=NDIM
C!
C!      do K=1,NDMQ
C!         WRITE (iUnitOutput,1180) K,ALTD(K),CFH3pHp(K),CFH3pEL(K),CFH3pH(K),
C!     $        CFH3pH2(K)
C!      enddo
C!      
C!      IF (NDIM.LT.NPT2) GO TO 591
C!      
C!      NDMQ=NPT3
C!      
C!      IF (NDIM.LT.NPT4) NDMQ=NDIM
C!      
C!      do K=NPT2,NDMQ,2
C!         WRITE (iUnitOutput,1180) K,ALTD(K),CFH3pHp(K),CFH3pEL(K),CFH3pH(K),
C!     $        CFH3pH2(K)
C!      enddo
C!      
C!      IF (NDIM.LT.NPT4) GO TO 591
C!      
C!      NDMQ=NPT5
C!      
C!      IF (NDIM.LT.NPT6) NDMQ=NDIM
C!      
C!      do K=NPT4,NDMQ,5
C!         WRITE (iUnitOutput,1180) K,ALTD(K),CFH3pHp(K),CFH3pEL(K),CFH3pH(K),
C!     $        CFH3pH2(K)
C!      enddo
C!      
C!      IF (NDIM.LT.NPT6) GO TO 591
C!      
C!      do K=NPT6,NDIM,10
C!         WRITE (iUnitOutput,1180) K,ALTD(K),CFH3pHp(K),CFH3pEL(K),CFH3pH(K),
C!     $        CFH3pH2(K)
C!      enddo
C!591   CONTINUE

C!1      WRITE (iUnitOutput,1247)
C!11247  FORMAT(1H1,50X,'COLLISION FREQUENCIES FOR HELIUM')
C!1      WRITE(iUnitOutput,1248)
C!11248  FORMAT(12X,'ALT',7X,'CFHEN2',6X,'CFHEO2',6X,'CFHEO',7X,
C!1     ;'CFHEHE',6X,'CFHEH',7X,'CFHEOX',6X,'CFHEHD',6X,'CFHEEL')
C!1      NDMQ=NPT1
C!1      IF (NDIM.LT.NPT2) NDMQ=NDIM
C!1      DO 1231 K=1,NDMQ
C!1      WRITE (iUnitOutput,1180) K,ALTD(K),CFHEN2(K),CFHEO2(K),CFHEO(K),
C!1     $CFHEHE(K),CFHEH(K),CFHEOX(K),CFHEHD(K),CFHEEL(K)
C!11231  CONTINUE
C!1      IF (NDIM.LT.NPT2) GO TO 1291
C!1      NDMQ=NPT3
C!1      IF (NDIM.LT.NPT4) NDMQ=NDIM
C!1      DO 1241 K=NPT2,NDMQ,2
C!1      WRITE (iUnitOutput,1180) K,ALTD(K),CFHEN2(K),CFHEO2(K),CFHEO(K),
C!1     $CFHEHE(K),CFHEH(K),CFHEOX(K),CFHEHD(K),CFHEEL(K)
C!11241  CONTINUE
C!1      IF (NDIM.LT.NPT4) GO TO 1291
C!1      NDMQ=NPT5
C!1      IF (NDIM.LT.NPT6) NDMQ=NDIM
C!1      DO 1251 K=NPT4,NDMQ,5
C!1      WRITE (iUnitOutput,1180) K,ALTD(K),CFHEN2(K),CFHEO2(K),CFHEO(K),
C!1     $CFHEHE(K),CFHEH(K),CFHEOX(K),CFHEHD(K),CFHEEL(K)
C!11251  CONTINUE
C!1      IF (NDIM.LT.NPT6) GO TO 1291
C!1      DO 1261 K=NPT6,NDIM,10
C!1      WRITE (iUnitOutput,1180) K,ALTD(K),CFHEN2(K),CFHEO2(K),CFHEO(K),
C!1     $CFHEHE(K),CFHEH(K),CFHEOX(K),CFHEHD(K),CFHEEL(K)
C!11261  CONTINUE
C!11291  CONTINUE

      WRITE (iUnitOutput,2247)
2247  FORMAT(1H1,50X,'COLLISION FREQUENCIES FOR HYDROGEN')
C!      WRITE(iUnitOutput,2248)
C!2248  FORMAT(12X,'ALT',7X,'CFHpH3p',7X,'CFHpH',7X,'CFHpEL',8X,
C!     ;'CFHpH2')
C!      
C!      NDMQ=NPT1
C!      
C!      IF (NDIM.LT.NPT2) NDMQ=NDIM
C!      
C!      do K=1,NDMQ
C!         WRITE (iUnitOutput,1180) K,ALTD(K),CFHpH3p(K),CFHpH(K),CFHpEL(K),CFHpH2(K)
C!      enddo
C!
C!      IF (NDIM.LT.NPT2) GO TO 2291
C!
C!      NDMQ=NPT3
C!
C!      IF (NDIM.LT.NPT4) NDMQ=NDIM
C!
C!      do K=NPT2,NDMQ,2
C!         WRITE (iUnitOutput,1180) K,ALTD(K),CFHpH3p(K),CFHpH(K),CFHpEL(K),CFHpH2(K)
C!      enddo
C!
C!      IF (NDIM.LT.NPT4) GO TO 2291
C!
C!      NDMQ=NPT5
C!
C!      IF (NDIM.LT.NPT6) NDMQ=NDIM
C!
C!      do K=NPT4,NDMQ,5
C!         WRITE (iUnitOutput,1180) K,ALTD(K),CFHpH3p(K),CFHpH(K),CFHpEL(K),CFHpH2(K)
C!      enddo
C!
C!      IF (NDIM.LT.NPT6) GO TO 2291
C!
C!      do K=NPT6,NDIM,10
C!         WRITE (iUnitOutput,1180) K,ALTD(K),CFHpH3p(K),CFHpH(K),CFHpEL(K),CFHpH2(K)
C!      enddo
C!2291  CONTINUE

      WRITE (iUnitOutput,3247)
3247  FORMAT(1H1,50X,'COLLISION FREQUENCIES FOR ELECTRONS')
C!      WRITE(iUnitOutput,3248)
C!3248  FORMAT(12X,'ALT',7X,'CFELHp',6X,'CFELH3p',6X,'CFELH2',7X,
C!     ;'CFELH')
C! 
C!      NDMQ=NPT1
C!      
C!      IF (NDIM.LT.NPT2) NDMQ=NDIM
C!
C!      do K=1,NDMQ
C!         WRITE (iUnitOutput,1180) K,ALTD(K),CFELHp(K),CFELH3p(K),CFELH2(K),CFELH(K)
C!      enddo
C!      IF (NDIM.LT.NPT2) GO TO 3291
C!      NDMQ=NPT3
C!      IF (NDIM.LT.NPT4) NDMQ=NDIM
C!      DO 3241 K=NPT2,NDMQ,2
C!      WRITE (iUnitOutput,1180) K,ALTD(K),CFELN2(K),CFELO2(K),CFELO(K),
C!     $CFELHE(K),CFELH(K),CFELOX(K),CFELHL(K),CFELHD(K)
C!3241  CONTINUE
C!      IF (NDIM.LT.NPT4) GO TO 3291
C!      NDMQ=NPT5
C!      IF (NDIM.LT.NPT6) NDMQ=NDIM
C!      DO 3251 K=NPT4,NDMQ,5
C!      WRITE (iUnitOutput,1180) K,ALTD(K),CFELN2(K),CFELO2(K),CFELO(K),
C!     $CFELHE(K),CFELH(K),CFELOX(K),CFELHL(K),CFELHD(K)
C!3251  CONTINUE
C!      IF (NDIM.LT.NPT6) GO TO 3291
C!      DO 3261 K=NPT6,NDIM,10
C!      WRITE (iUnitOutput,1180) K,ALTD(K),CFELN2(K),CFELO2(K),CFELO(K),
C!     $CFELHE(K),CFELH(K),CFELOX(K),CFELHL(K),CFELHD(K)
C!3261  CONTINUE
C!3291  CONTINUE

      WRITE (iUnitOutput,1013)
1013  FORMAT(1H1,45X,'INITIAL OXYGEN PARAMETERS')
      WRITE(iUnitOutput,1021)
1021  FORMAT(16X,'ALT',10X,'VELOCITY',8X,'MACH NO',9X,'DENSITY',9X,
     ;'PRESSURE',6X,'TEMPERATURE',/)
      K=0
CALEX XM stands for Mach Number      
      XM=USURFO/WSURFO
      DNS1=DSURFO/XMSO
      WRITE(iUnitOutput,1022) K,ALTMIN,USURFO,XM,DNS1,PSURFO,TSURFO
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 630 K=1,NDMQ
      US=SQRT(GAMMA*POXYG(K)/DOXYG(K))
      XM=UOXYG(K)/US
      DNS1=DOXYG(K)/XMSO
      WRITE(iUnitOutput,1022) K,ALTD(K),UOXYG(K),XM,DNS1,POXYG(K),TOXYG(K)
630   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 690
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 640 K=NPT2,NDMQ,2
      US=SQRT(GAMMA*POXYG(K)/DOXYG(K))
      XM=UOXYG(K)/US
      DNS1=DOXYG(K)/XMSO
      WRITE(iUnitOutput,1022) K,ALTD(K),UOXYG(K),XM,DNS1,POXYG(K),TOXYG(K)
640   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 690
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 650 K=NPT4,NDMQ,5
      US=SQRT(GAMMA*POXYG(K)/DOXYG(K))
      XM=UOXYG(K)/US
      DNS1=DOXYG(K)/XMSO
      WRITE(iUnitOutput,1022) K,ALTD(K),UOXYG(K),XM,DNS1,POXYG(K),TOXYG(K)
650   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 690
      DO 660 K=NPT6,NDIM,10
      US=SQRT(GAMMA*POXYG(K)/DOXYG(K))
      XM=UOXYG(K)/US
      DNS1=DOXYG(K)/XMSO
      WRITE(iUnitOutput,1022) K,ALTD(K),UOXYG(K),XM,DNS1,POXYG(K),TOXYG(K)
660   CONTINUE
690   CONTINUE
      K=NDIM1
      XM=UBGNDO/WBGNDO
      DNS1=DBGNDO/XMSO
      WRITE(iUnitOutput,1022) K,ALTMAX,UBGNDO,XM,DNS1,PBGNDO,TBGNDO
      WRITE (iUnitOutput,1055)
1055  FORMAT(1H1,45X,'INITIAL HELIUM PARAMETERS')
      WRITE(iUnitOutput,1056)
1056  FORMAT(16X,'ALT',10X,'VELOCITY',8X,'MACH NO',9X,'DENSITY',9X,
     ;'PRESSURE',6X,'TEMPERATURE',/)
      K=0
      XM=USURHE/WSURHE
      DNS1=DSURHE/XMSHE
      WRITE(iUnitOutput,1022) K,ALTMIN,USURHE,XM,DNS1,PSURHE,TSURHE
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 639 K=1,NDMQ
CALEX fix arithmatic problem
CALEX      US=SQRT(GAMMA*PHEL(K)/DHEL(K))
CALEX      XM=UHEL(K)/US
         XM=0.
      DNS1=DHEL(K)/XMSHE
      WRITE(iUnitOutput,1022) K,ALTD(K),UHEL(K),XM,DNS1,PHEL(K),THEL(K)
639   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 699
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 649 K=NPT2,NDMQ,2
CALEX fix arithmatic problem
CALEX      US=SQRT(GAMMA*PHEL(K)/DHEL(K))
CALEX      XM=UHEL(K)/US
         XM=0.
      DNS1=DHEL(K)/XMSHE
      WRITE(iUnitOutput,1022) K,ALTD(K),UHEL(K),XM,DNS1,PHEL(K),THEL(K)
649   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 699
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 659 K=NPT4,NDMQ,5
CALEX      US=SQRT(GAMMA*PHEL(K)/DHEL(K))
CALEX      XM=UHEL(K)/US
         XM=0.
      DNS1=DHEL(K)/XMSHE
      WRITE(iUnitOutput,1022) K,ALTD(K),UHEL(K),XM,DNS1,PHEL(K),THEL(K)
659   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 699
      DO 669 K=NPT6,NDIM,10
CALEX      US=SQRT(GAMMA*PHEL(K)/DHEL(K))
CALEX      XM=UHEL(K)/US
         XM=0.
      DNS1=DHEL(K)/XMSHE
      WRITE(iUnitOutput,1022) K,ALTD(K),UHEL(K),XM,DNS1,PHEL(K),THEL(K)
669   CONTINUE
699   CONTINUE
      K=NDIM1
CALEX      XM=UBGNHE/WBGNHE
CALEX this is just a place holding number!!!!
      XM=0.
      DNS1=DBGNHE/XMSHE
      WRITE(iUnitOutput,1022) K,ALTMAX,UBGNHE,XM,DNS1,PBGNHE,TBGNHE
      WRITE (iUnitOutput,1010)
1010  FORMAT(1H1,45X,'INITIAL HYDROGEN PARAMETERS')
      WRITE(iUnitOutput,1021)
      K=0
      XM=USURFH/WSURFH
      DNS1=DSURFH/XMSH
      WRITE(iUnitOutput,1022) K,ALTMIN,USURFH,XM,DNS1,PSURFH,TSURFH
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 730 K=1,NDMQ
      US=SQRT(GAMMA*PHYD(K)/DHYD(K))
      XM=UHYD(K)/US
      DNS1=DHYD(K)/XMSH
      WRITE(iUnitOutput,1022) K,ALTD(K),UHYD(K),XM,DNS1,PHYD(K),THYD(K)
730   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 790
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 740 K=NPT2,NDMQ,2
      US=SQRT(GAMMA*PHYD(K)/DHYD(K))
      XM=UHYD(K)/US
      DNS1=DHYD(K)/XMSH
      WRITE(iUnitOutput,1022) K,ALTD(K),UHYD(K),XM,DNS1,PHYD(K),THYD(K)
740   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 790
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 750 K=NPT4,NDMQ,5
      US=SQRT(GAMMA*PHYD(K)/DHYD(K))
      XM=UHYD(K)/US
      DNS1=DHYD(K)/XMSH
      WRITE(iUnitOutput,1022) K,ALTD(K),UHYD(K),XM,DNS1,PHYD(K),THYD(K)
750   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 790
      DO 760 K=NPT6,NDIM,10
      US=SQRT(GAMMA*PHYD(K)/DHYD(K))
      XM=UHYD(K)/US
      DNS1=DHYD(K)/XMSH
      WRITE(iUnitOutput,1022) K,ALTD(K),UHYD(K),XM,DNS1,PHYD(K),THYD(K)
760   CONTINUE
790   CONTINUE
      K=NDIM1
      XM=UBGNDH/WBGNDH
      DNS1=DBGNDH/XMSH
      WRITE(iUnitOutput,1022) K,ALTMAX,UBGNDH,XM,DNS1,PBGNDH,TBGNDH
      WRITE (iUnitOutput,1011)
1011  FORMAT(1H1,45X,'INITIAL ELECTRON PARAMETERS')
      WRITE(iUnitOutput,1021)
      K=0
      XM=USURFE/WSURFE
      DNS1=DSURFE/XMSE
      WRITE(iUnitOutput,1022) K,ALTMIN,USURFE,XM,DNS1,PSURFE,TSURFE
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 830 K=1,NDMQ
      US=SQRT(GAMMA*PELECT(K)/DELECT(K))
      XM=UELECT(K)/US
      DNS1=DELECT(K)/XMSE
      WRITE(iUnitOutput,1022) K,ALTD(K),UELECT(K),XM,DNS1,PELECT(K),TELECT(K)
830   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 890
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 840 K=NPT2,NDMQ,2
      US=SQRT(GAMMA*PELECT(K)/DELECT(K))
      XM=UELECT(K)/US
      DNS1=DELECT(K)/XMSE
      WRITE(iUnitOutput,1022) K,ALTD(K),UELECT(K),XM,DNS1,PELECT(K),TELECT(K)
840   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 890
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 850 K=NPT4,NDMQ,5
      US=SQRT(GAMMA*PELECT(K)/DELECT(K))
      XM=UELECT(K)/US
      DNS1=DELECT(K)/XMSE
      WRITE(iUnitOutput,1022) K,ALTD(K),UELECT(K),XM,DNS1,PELECT(K),TELECT(K)
850   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 890
      DO 860 K=NPT6,NDIM,10
      US=SQRT(GAMMA*PELECT(K)/DELECT(K))
      XM=UELECT(K)/US
      DNS1=DELECT(K)/XMSE
      WRITE(iUnitOutput,1022) K,ALTD(K),UELECT(K),XM,DNS1,PELECT(K),TELECT(K)
860   CONTINUE
890   CONTINUE
      K=NDIM1
      XM=UBGNDE/WBGNDE
      DNS1=DBGNDE/XMSE
      WRITE(iUnitOutput,1022) K,ALTMAX,UBGNDE,XM,DNS1,PBGNDE,TBGNDE
      WRITE(iUnitOutput,1024)
1024  FORMAT(1H1,40X,'INITIAL ELECTRIC FIELD AND SOURCE PARAMETERS')
      WRITE(iUnitOutput,1025)
1025  FORMAT(13X,'ALT',6X,'EFIELD',6X,'FCLSNO',6X,'ECLSNO',6X,'FCLSHE',
     ;6X,'ECLSHE',6X,'FCLSNH',6X,'ECLSNH',6X,'FCLSNE',6X,'ECLSNE')
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 930 K=1,NDMQ
      WRITE(iUnitOutput,1026) K,ALTD(K),EFIELD(K),FCLSNO(K),ECLSNO(K),FCLSHE(K),
     ;ECLSHE(K),FCLSNH(K),ECLSNH(K),FCLSNE(K),ECLSNE(K)
930   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 990
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 940 K=NPT2,NDMQ,2
      WRITE(iUnitOutput,1026) K,ALTD(K),EFIELD(K),FCLSNO(K),ECLSNO(K),FCLSHE(K),
     ;ECLSHE(K),FCLSNH(K),ECLSNH(K),FCLSNE(K),ECLSNE(K)
940   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 990
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 950 K=NPT4,NDMQ,5
      WRITE(iUnitOutput,1026) K,ALTD(K),EFIELD(K),FCLSNO(K),ECLSNO(K),FCLSHE(K),
     ;ECLSHE(K),FCLSNH(K),ECLSNH(K),FCLSNE(K),ECLSNE(K)
950   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 990
      DO 960 K=NPT6,NDIM,10
      WRITE(iUnitOutput,1026) K,ALTD(K),EFIELD(K),FCLSNO(K),ECLSNO(K),FCLSHE(K),
     ;ECLSHE(K),FCLSNH(K),ECLSNH(K),FCLSNE(K),ECLSNE(K)
960   CONTINUE
990   CONTINUE
999   CONTINUE
      WRITE (iUnitOutput,2013)
2013  FORMAT(1H1,45X,'HEAT CONDUCTIVITIES')
      WRITE(iUnitOutput,2021)
2021  FORMAT(16X,'ALT',10X,'OXYGEN',10X,'HELIUM',9X,'HYDROGEN',9X,
     ;'ELECTRONS'/)
      K=0
      WRITE(iUnitOutput,1022) K,ALTMIN,TCSFO,TCSFHE,TCSFH,TCSFE
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 2630 K=1,NDMQ
      WRITE(iUnitOutput,1022) K,ALTD(K),TCONO(K),TCONHE(K),TCONH(K),TCONE(K)
2630  CONTINUE
      IF (NDIM.LT.NPT2) GO TO 2690
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 2640 K=NPT2,NDMQ,2
      WRITE(iUnitOutput,1022) K,ALTD(K),TCONO(K),TCONHE(K),TCONH(K),TCONE(K)
2640  CONTINUE
      IF (NDIM.LT.NPT4) GO TO 2690
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 2650 K=NPT4,NDMQ,5
      WRITE(iUnitOutput,1022) K,ALTD(K),TCONO(K),TCONHE(K),TCONH(K),TCONE(K)
2650   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 2690
      DO 2660 K=NPT6,NDIM,10
      WRITE(iUnitOutput,1022) K,ALTD(K),TCONO(K),TCONHE(K),TCONH(K),TCONE(K)
2660   CONTINUE
2690   CONTINUE
      K=NDIM1
      WRITE(iUnitOutput,1022) K,ALTMAX,TCBGO,TCBGHE,TCBGH,TCBGE
1019  FORMAT(3X,I3,0PF10.2,2X,11(1PE11.2))
1022  FORMAT(3X,I3,0PF14.2,2X,6(1PE17.5E3))
1026  FORMAT(3X,I3,0PF11.2,2X,9(1PE13.4E3))
1180  FORMAT(3X,I3,0PF10.2,2X,8(1PE13.4E3))
1028  FORMAT(3X,I3,0PF14.2,2X,2(1PE17.5E3))
1031  FORMAT(3X,I3,0PF14.2,2X,4(1PE17.5E3))

      endif
      RETURN
      END



      

CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C     ALEX(10/11/04): I THINK THIS IS A COLD START ROUTINE FOR DEALING WITH
C     A LACK OF RESTART FILE. BASICALLY THE VELOCITY IS SET TO ZERO AND 
C     THE OTHER GRID VALUES ARE SET TO VALUES THAT WON'T CRASH.
C     (11/9/04) I also see that source terms and collision terms are set
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
      
      
      SUBROUTINE STRT1
      use ModCommonVariables
!     REAL jp1,jp2,jp3,jp4,kc1,kc2,kc3,kc6,kc7,kc8,kr1,kr2
      real DensityHp,DensityH3p
C     ALEX define the reaction rates, label by reaction number
C     ALEX j is for photochemistry, k is for regular chemistry
      
c     ! H2+h\nu     --> H+ + H + e
      jp1=1.9E-11
!      jp1=9.5E-11
      !             --> H2+ + e
      jp2=9.9E-10
      !jp2=5.4E-10
      ! H+h\nu      --> H+
      jp3=1.0E-9
      !jp3=7.3E-10
      ! H2O+h\nu    --> H+ + OH +e
      jp4=4.2E-10
      !jp4=1.3E-10

      ! H2+ + H2    --> H3+ +H
      kc1=2.E-9
      ! H+ + H2 + M --> H3+ + M
      kc2=3.2E-29
      !kc2=0.0
      
      ! H+ + CH4    --> CH3+ + H2  
      !             --> CH4+ + H
      kc3=4.5E-9
      !kc3=4.15E-9
      !kc3=0.0
      ! H3+ + CH4   --> CH5+ + H2 
      kc6=2.4E-9
      !kc6=0.0
      ! H3+ + H2O   --> H3O+ + H2
      kc7=5.3E-9
      !kc7=0.0
      ! H+ + H2O    --> H2O+ + H
      kc8=8.2E-9
      !kc8=0.0
      ! H+ + e      --> H + h\nu
      kr1=1.91E-10
      !kr1=2.0E-12
      !kr1=0.0
      ! H3+ + e     --> H2 + H
      !             --> 3H
      kr2=1.73E-6
      !kr2=4.6E-6
!note kr2 includes H3+ + e --> H2 + H and --> 3H

      ! H+ + H2(\nu>3) --> H2+ + H
      do i=1,nDim 
         call get_rate(ALTD(i)/100000.0,kc9(i))
      enddo
      
      
      !kc9(:)=0.0*kc9(:)
C     
C     
C     
C     
C     PHIOX=7.00E-7
C     
C     DEFINE THE HE PHOTOIONIZATION RATE
C     
      PHIHE=1.30E-7
C     
C     C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C     C
C     DEFINE THE GAS PARAMETERS AT THE LOWER BOUNDARY                  C
C     C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C     C
      USURFO=0.
      USURFH=0.
      USURHE=0.
      USURFE=0.
      CALL MODATM(ALTMIN,XNH2,XNH,XNH2O,XNCH4,TEMP)

CALEX I pretend that for plasma parameters, O is H3 and HE is
CALEX chemical equilibrium value for H2+ this allow me to just
CALEX change the chemistry but leave the rest of the code the same  
      TSURFO=TEMP
      TSURFH=TEMP
      TSURHE=TEMP
      TSURFE=TEMP

      call calc_chemical_equilibrium(DensityHp,DensityH3p)
      DSURFO=XMSO*DensityH3p
      DSURFH=XMSH*DensityHp
      write(*,*) 'H+(1400km)=',DensityHp,', H3+(1400km)=',DensityH3p


C I have used numerically calculated chemical equilibrium
C solution for T=800k.       
!      DSURFO=XMSO*6489.69
!c      DSURHE=XMSHE*jp2/kc1
!      DSURFHE=0.
!      DSURFH=XMSH*1343.64
C I have used numerically calculated chemical equilibrium
C solution for T=1000k.       
c      DSURFO=XMSO*4725.0
c      DSURFHE=0.
c      DSURFH=XMSH*368.0

C I have used numerically calculated chemical equilibrium
C solution for T=1500k.       
c      DSURFO=XMSO*560.0
c      DSURFHE=0.
c      DSURFH=XMSH*30.0


C I have used numerically calculated chemical equilibrium
C solution for T=1500k. with enhanced water and decreased CH4      
c      DSURFO=XMSO*11435.41
c      DSURFHE=0.
c      DSURFH=XMSH*1463.48

C I have used numerically calculated chemical equilibrium
C solution for T=100k. with reduced CH4 enhanced h2o      
C      DSURFO=XMSO*5509.0
C      DSURFHE=0.
C      DSURFH=XMSH*1124.0


      DSURFE=RTHDEL*DSURFH+RTOXEL*DSURFO
      PSURFO=RGASO*TSURFO*DSURFO
      PSURFH=RGASH*TSURFH*DSURFH
      PSURHE=RGASHE*TSURHE*DSURHE
      PSURFE=RGASE*TSURFE*DSURFE
      WSURFO=SQRT(GAMMA*RGASO*TSURFO)
      WSURFH=SQRT(GAMMA*RGASH*TSURFH)
      WSURHE=SQRT(GAMMA*RGASHE*TSURHE)
      WSURFE=SQRT(GAMMA*RGASE*TSURFE)
C     
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C     

      

      DO 20 I=1,NDIM
CALEX SOURCE COEF?       
         FFHpp1(I)=jp1*XH2(I)
         FFHpp3(I)=jp3*XH(I)
         FFHpp4(I)=jp4*XH2O(I)
         FFHpc2(I)=-kc2*XH2(I)*XH2(I)
         FFHpc3(I)=-kc3*XCH4(I)
         FFHpc8(I)=-kc8*XH2O(I)
         FFHpc9(I)=-kc9(I)*XH2(I)
         FFHpr1(I)=-kr1
CALEX write out source coeff
CALEX         write(26,*) FFHpp1(I),FFHpp3(I),FFHpp4(I),FFHpc2(I),FFHpc3(I),FFHpc8(I),FFHpr1(I)
        

         FFH3pc1(I)=kc1*(jp2/kc1)*XH2(I)
         FFH3pc2(I)=kc2*XH2(I)*XH2(I)
         FFH3pc6(I)=-kc6*XCH4(I)
         FFH3pc7(I)=-kc7*XH2O(I)
         FFH3pr2(I)=-kr2

CALEX write out source coeff
CALEX         write(27,*) FFH3pc1(I),FFH3pc2(I),FFH3pc6(I),FFH3pc7(I),FFH3pr2(I)

CALEX CL=COLLISION COEF, CF=collision freq ?         

CALEX the coulomb collisions
CAlex H+ and H3+         
         CLHpH3p(I)=1.905*4.**1.5/XMSO
CALEX electron H+ and electron H3+
         CLELHp(I)=54.5/XMSH
         CLELH3p(I)=54.5/XMSO
       
CALEX  ion neutrals
         CLHpH(I)=2.65E-10*XH(I)
         CFHpH2(I)=2.6E-9*XH2(I)*(.82/.667)**.5
         CFH3pH(I)=2.6E-9*XH(I)*(.667/.75)**.5
         CFH3pH2(I)=2.6E-9*XH2(I)*(.82/1.2)**.5
CALEX electron H, e H2 done in collis
         CLELH(I)=4.5E-9*XH(I)

         GRAVTY(I)=-3.79E22/RAD(I)**2
         Centrifugal(I)=RAD(I)*((sin((90.-GLAT)*3.14159/180.))**2)*Omega**2
         
 20   CONTINUE
c      GRAVTY(nDim)=GRAVTY(nDim)*0.0
cAlex
      NEXP=3
      WRITE(*,*) CURR(1),RAD(1),NEXP
cendAlex      
      CRRX=CURR(1)*RAD(1)**NEXP
      DO 25 I=1,NDIM
         CURR(I)=CRRX/RAD(I)**NEXP
 25   CONTINUE
C     SGN1=1.
C     IF (CURR(1).LT.0.) SGN1=-1.
C     IF (ABS(CURR(1)).LT.1.E-4) SGN1=0.
C     DO 30 I=NDIM-250,NDIM
C     CURR(I)=SGN1*0.2998*(RAD(1)/RAD(I))**NEXP
C     30    CONTINUE
      
CALEX CT & CM = energy collision term coef?
CALEX Based on Nagy p. 83, I believe that CT is the coeff
CALEX of the term that is due to temperature difference or
CALEX heat flow between species, and CM is the term due to 
CALEX frictional heating between species moving through each other

CALEX CTOXN2 = 3*R_o*M_o/(M_o+M_{N2}) see nagy p.83
      CTHpH=3.*RGASH*XMSH/(XMSH+XMSH)
      CTHpH2=3.*RGASH*XMSH/(XMSH+2.*XMSH)
      CTHpH3p=3.*RGASH*XMSH/(XMSH+XMSO)
      CTHpEL=3.*RGASH*XMSH/(XMSH+XMSE)

      CTH3pH=3.*RGASO*XMSO/(XMSO+XMSH)
      CTH3pH2=3.*RGASO*XMSO/(XMSO+2.*XMSH)
      CTH3pHp=3.*RGASO*XMSO/(XMSO+XMSH)
      CTH3pEL=3.*RGASO*XMSO/(XMSO+XMSE)

      CTELH=3.*RGASE*XMSE/(XMSE+XMSH)
      CTELH2=3.*RGASE*XMSE/(XMSE+2.*XMSH)
      CTELHp=3.*RGASE*XMSE/(XMSE+XMSH)
      CTELH3p=3.*RGASE*XMSE/(XMSE+XMSO)
      
CALEX CMOXN2 = M_{N2}/(M_o+M_{N2}) see nagy p.83
      CMHpH=XMSH/(XMSH+XMSH)
      CMHpH2=2.*XAMU/(XMSH+2.*XAMU)
      CMHpH3p=XMSO/(XMSH+XMSO)
      CMHpEL=XMSE/(XMSH+XMSE)
       
      CMH3pH=XMSH/(XMSO+XMSH)
      CMH3pH2=2.*XAMU/(XMSO+2.*XAMU)
      CMH3pHp=XMSH/(XMSO+XMSH)
      CMH3pEL=XMSE/(XMSO+XMSE)
       
      CMELH=XMSH/(XMSE+XMSH)
      CMELH2=2.*XAMU/(XMSE+2.*XAMU)
      CMELHp=XMSH/(XMSE+XMSH)
      CMELH3p=XMSO/(XMSE+XMSO)
     
C     ALEX(10/11/04): 
C     TRY SETTING THE PLASMA PARAMETERS HERE TO THE SURFACE VALUES

      if(IsRestart) RETURN

      do K=1,NDIM
         DHYD(K)=DSURFH*exp(-(ALTD(k)-1400.E5)/5000.E5)
         UOXYG(K)=0
         POXYG(K)=PSURFO*exp(-(ALTD(k)-1400.E5)/5000.E5)
         DOXYG(K)=DSURFO*exp(-(ALTD(k)-1400.E5)/5000.E5)
         TOXYG(K)=TSURFO
         UHYD(K)=0
         PHYD(K)=PSURFH*exp(-(ALTD(k)-1400.E5)/5000.E5)
         THYD(K)=TSURFH
         UHEL(K)=0
         PHEL(K)=PSURHE
         DHEL(K)=DSURHE
         THEL(K)=TSURHE
         DELECT(K)=DSURFE*exp(-(ALTD(k)-1400.E5)/5000.E5)
         UELECT(K)=0
         PELECT(K)=PSURFE*exp(-(ALTD(k)-1400.E5)/5000.E5)
         TELECT(K)=TSURFE
         
         
      enddo
      
      
      


      RETURN
      END
