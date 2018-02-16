Module ModCrcmGrid
  implicit none
  
  ! define dimensions of CRCM grids
  integer,parameter :: np1=76,nt1=48,neng1=12,npit1=12!,nspec1=1  
  integer,parameter :: nm=35,nk=28 ! dimension of CRCM magnetic moment and K

  integer,parameter :: np=76    ! dimension of the CRCM latitude grid
  integer,parameter :: nt=48    ! dimension of the CRCM local-time grid
  integer,parameter :: neng=12  ! dimension of the CRCM energy grid
  integer,parameter :: npit=12  ! dimension of the CRCM pitch-angle grid

  ! These have to be initialized so that IM_set_grid does not fail on non-IM PEs
  real:: xlat(np) = 0.0, phi(nt1)=0.0


  real, parameter :: xlat_data(0:77)=(/ &
       9.8403398252184129, 11.8094287214197298, 13.7766188250317825, &
15.7417393813253206, 17.7045308431118862, 19.6647678141488633, 21.6221087849777582, &
23.5762054159508949, 25.5266205749613988, 27.4728078468756607, 29.4141730052358952, &
31.3498827669633577, 33.2789638301013255, 35.2001491945587546, 37.1117859545565096, &
39.0116816193710108, 40.8967967548216080, 42.7628624926770371, 44.6035096815362593, &
46.4088994338998830, 48.1627588240703375, 49.8368552651133925, 51.3815093761009436, &
52.7245636235464019, 53.8230766081378960, 54.7200170499439693, 55.4875732183024866, &
56.1754757205603212, 56.8119981247867400, 57.4134304321522109, 57.9896627565749228, &
58.5470881551180042, 59.0900369677152426, 59.6215725342093847, 60.1439385717427939, &
60.6588221370404455, 61.1675448717067525, 61.6711449644955465, 62.1704778966003815, &
62.6662249793909538, 63.1589770242304738, 63.6492445877594051, 64.1374545568008614, &
64.6239996672321411, 65.1092248436063130, 65.5934511048143634, 66.0769755640852026, &
66.5600953346477127, 67.0430716712376551, 67.5261863191582847, 68.0097159010710044, &
68.4939438698263530, 68.9791690462005107, 69.4657141566317904, 69.9539258332205378, &
70.4441882741076029, 70.9369437340417051, 71.4326925243795756, 71.9320186262952319, &
72.4356255492731975, 72.9443499914867886, 73.4592352643317383, 73.9815995943178564, &
74.5131334532647145, 75.0560839734092440, 75.6135076644050201, 76.1897399888277391, &
76.7911680273249857, 77.4276972617405619, 78.1155980564511054, 78.8831567861305700, &
79.7800963741629943, 80.8786008210180256, 82.2216559222371330, 83.7663121676587963, &
85.4404094624754862, 87.1942709870800599, 88.9996559369669313/)


  real :: xlatr(np), xmlt(nt), dlat(np1), energy(neng), sinAo(npit),&
          Ebound(neng+1)

  real :: d4Element_C(np,nm,nk) !4D element (dlat*dphi*dmm*dk)
  
  logical, parameter :: UseExpandedGrid =.true.

  ! Define MPI parameters affecting grid
  integer :: iProc, nProc, iComm, nLonPar, MinLonPar, MaxLonPar
  integer, allocatable :: nLonPar_P(:),nLonBefore_P(:)
  integer ::iProcLeft, iProcRight, iLonLeft, iLonRight
  integer :: iProcMidnight, iLonMidnight
end Module ModCrcmGrid

