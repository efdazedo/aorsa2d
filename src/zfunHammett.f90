module hammett

contains

complex function Zfun(zeta)
  ! calculate the plasma dispersion function Z(zeta)
  ! by calling the wofz.f subroutine.

  use constants

  implicit none
  complex zeta
  
  real(kind=dbl) :: x, y
  logical :: flag
  real(kind=dbl), parameter :: sqrt_pi = 1.772453850905516
  
  call wofz(real(zeta,kind=dbl), real(aimag(zeta),kind=dbl), x, y, flag)
  Zfun = sqrt_pi*cmplx(-y,x)
  
  return
end function Zfun

! for a purely real argument:

complex function Zfunr(z_real)
  use constants
  implicit none
  real z_real
  
  real(kind=dbl) :: x, y
  logical :: flag
  
  real*8, parameter :: sqrt_pi = 1.772453850905516
  
  call wofz(real(z_real,kind=dbl), 0d0, x, y, flag)
  if(flag)then 
    write(*,*) 'CRAP: wofz failed'
    stop
  endif
  Zfunr = sqrt_pi*cmplx(-y,x)
  
  return
end function Zfunr

! GWH: the following directly evaluates the equivalent of the Z function 
! using various expansion formulas.  While the paper it is based on says it
! is faster than previous algorithms, there may be ways to evaluate the Z
! function even faster, such as by using Pade approximations (rational
! functions) fit to this routine.
      
!      ALGORITHM 680, COLLECTED ALGORITHMS FROM ACM.
!      THIS WORK PUBLISHED IN TRANSACTIONS ON MATHEMATICAL SOFTWARE,
!      VOL. 16, NO. 1, PP. 47.
      SUBROUTINE WOFZ (XI, YI, U, V, FLAG)
!
!  GIVEN A COMPLEX NUMBER Z = (XI,YI), THIS SUBROUTINE COMPUTES
!  THE VALUE OF THE FADDEEVA-FUNCTION W(Z) = EXP(-Z**2)*ERFC(-I*Z),
!  WHERE ERFC IS THE COMPLEX COMPLEMENTARY ERROR-FUNCTION AND I
!  MEANS SQRT(-1).
!  THE ACCURACY OF THE ALGORITHM FOR Z IN THE 1ST AND 2ND QUADRANT
!  IS 14 SIGNIFICANT DIGITS; IN THE 3RD AND 4TH IT IS 13 SIGNIFICANT
!  DIGITS OUTSIDE A CIRCULAR REGION WITH RADIUS 0.126 AROUND A ZERO
!  OF THE FUNCTION.
!  ALL REAL VARIABLES IN THE PROGRAM ARE DOUBLE PRECISION.
!
!
!  THE CODE CONTAINS A FEW COMPILER-DEPENDENT PARAMETERS :
!     RMAXREAL = THE MAXIMUM VALUE OF RMAXREAL EQUALS THE ROOT OF
!                RMAX = THE LARGEST NUMBER WHICH CAN STILL BE
!                IMPLEMENTED ON THE COMPUTER IN DOUBLE PRECISION
!                FLOATING-POINT ARITHMETIC
!     RMAXEXP  = LN(RMAX) - LN(2)
!     RMAXGONI = THE LARGEST POSSIBLE ARGUMENT OF A DOUBLE PRECISION
!                GONIOMETRIC FUNCTION (DCOS, DSIN, ...)
!  THE REASON WHY THESE PARAMETERS ARE NEEDED AS THEY ARE DEFINED WILL
!  BE EXPLAINED IN THE CODE BY MEANS OF COMMENTS
!
!
!  PARAMETER LIST
!     XI     = REAL      PART OF Z
!     YI     = IMAGINARY PART OF Z
!     U      = REAL      PART OF W(Z)
!     V      = IMAGINARY PART OF W(Z)
!     FLAG   = AN ERROR FLAG INDICATING WHETHER OVERFLOW WILL
!              OCCUR OR NOT; TYPE LOGICAL;
!              THE VALUES OF THIS VARIABLE HAVE THE FOLLOWING
!              MEANING :
!              FLAG=.FALSE. : NO ERROR CONDITION
!              FLAG=.TRUE.  : OVERFLOW WILL OCCUR, THE ROUTINE
!                             BECOMES INACTIVE
!  XI, YI      ARE THE INPUT-PARAMETERS
!  U, V, FLAG  ARE THE OUTPUT-PARAMETERS
!
!  FURTHERMORE THE PARAMETER FACTOR EQUALS 2/SQRT(PI)
!
!  THE ROUTINE IS NOT UNDERFLOW-PROTECTED BUT ANY VARIABLE CAN BE
!  PUT TO 0 UPON UNDERFLOW;
!
!  REFERENCE - GPM POPPE, CMJ WIJERS; MORE EFFICIENT COMPUTATION OF
!  THE COMPLEX ERROR-FUNCTION, ACM TRANS. MATH. SOFTWARE (1990)
!  VOL. 16, NO. 1, PP. 47.
!
!
!
!
!
      IMPLICIT DOUBLE PRECISION (A-H, O-Z)
!
      LOGICAL A, B, FLAG
      PARAMETER (FACTOR   = 1.12837916709551257388D0,   &
                 RMAXREAL = 0.5D+154,                   &
                 RMAXEXP  = 708.503061461606D0,         &
                 RMAXGONI = 3.53711887601422D+15)
!
      FLAG = .FALSE.
!
      XABS = DABS(XI)
      YABS = DABS(YI)
      X    = XABS/6.3
      Y    = YABS/4.4
!
!
!     THE FOLLOWING IF-STATEMENT PROTECTS
!     QRHO = (X**2 + Y**2) AGAINST OVERFLOW
!
      IF ((XABS.GT.RMAXREAL).OR.(YABS.GT.RMAXREAL)) GOTO 100
!
      QRHO = X**2 + Y**2
!
      XABSQ = XABS**2
      XQUAD = XABSQ - YABS**2
      YQUAD = 2*XABS*YABS
!
      A     = QRHO.LT.0.085264D0
!
      IF (A) THEN
!
!  IF (QRHO.LT.0.085264D0) THEN THE FADDEEVA-FUNCTION IS EVALUATED
!  USING A POWER-SERIES (ABRAMOWITZ/STEGUN, EQUATION (7.1.5), P.297)
!  N IS THE MINIMUM NUMBER OF TERMS NEEDED TO OBTAIN THE REQUIRED
!  ACCURACY
!
        QRHO  = (1-0.85*Y)*DSQRT(QRHO)
        N     = IDNINT(6 + 72*QRHO)
        J     = 2*N+1
        XSUM  = 1.0/J
        YSUM  = 0.0D0
        DO 10 I=N, 1, -1
          J    = J - 2
          XAUX = (XSUM*XQUAD - YSUM*YQUAD)/I
          YSUM = (XSUM*YQUAD + YSUM*XQUAD)/I
          XSUM = XAUX + 1.0/J
 10     CONTINUE
        U1   = -FACTOR*(XSUM*YABS + YSUM*XABS) + 1.0
        V1   =  FACTOR*(XSUM*XABS - YSUM*YABS)
        DAUX =  DEXP(-XQUAD)
        U2   =  DAUX*DCOS(YQUAD)
        V2   = -DAUX*DSIN(YQUAD)
!
        U    = U1*U2 - V1*V2
        V    = U1*V2 + V1*U2
!
      ELSE
!
!  IF (QRHO.GT.1.O) THEN W(Z) IS EVALUATED USING THE LAPLACE
!  CONTINUED FRACTION
!  NU IS THE MINIMUM NUMBER OF TERMS NEEDED TO OBTAIN THE REQUIRED
!  ACCURACY
!
!  IF ((QRHO.GT.0.085264D0).AND.(QRHO.LT.1.0)) THEN W(Z) IS EVALUATED
!  BY A TRUNCATED TAYLOR EXPANSION, WHERE THE LAPLACE CONTINUED FRACTION
!  IS USED TO CALCULATE THE DERIVATIVES OF W(Z)
!  KAPN IS THE MINIMUM NUMBER OF TERMS IN THE TAYLOR EXPANSION NEEDED
!  TO OBTAIN THE REQUIRED ACCURACY
!  NU IS THE MINIMUM NUMBER OF TERMS OF THE CONTINUED FRACTION NEEDED
!  TO CALCULATE THE DERIVATIVES WITH THE REQUIRED ACCURACY
!
!
        IF (QRHO.GT.1.0) THEN
          H    = 0.0D0
          KAPN = 0
          QRHO = DSQRT(QRHO)
          NU   = IDINT(3 + (1442/(26*QRHO+77)))
        ELSE
          QRHO = (1-Y)*DSQRT(1-QRHO)
          H    = 1.88*QRHO
          H2   = 2*H
          KAPN = IDNINT(7  + 34*QRHO)
          NU   = IDNINT(16 + 26*QRHO)
        ENDIF
!
        B = (H.GT.0.0)
!
        IF (B) QLAMBDA = H2**KAPN
!
        RX = 0.0
        RY = 0.0
        SX = 0.0
        SY = 0.0
!
        DO 11 N=NU, 0, -1
          NP1 = N + 1
          TX  = YABS + H + NP1*RX
          TY  = XABS - NP1*RY
          C   = 0.5/(TX**2 + TY**2)
          RX  = C*TX
          RY  = C*TY
          IF ((B).AND.(N.LE.KAPN)) THEN
            TX = QLAMBDA + SX
            SX = RX*TX - RY*SY
            SY = RY*TX + RX*SY
            QLAMBDA = QLAMBDA/H2
          ENDIF
 11     CONTINUE
!
        IF (H.EQ.0.0) THEN
          U = FACTOR*RX
          V = FACTOR*RY
        ELSE
          U = FACTOR*SX
          V = FACTOR*SY
        END IF
!
        IF (YABS.EQ.0.0) U = DEXP(-XABS**2)
!
      END IF
!
!
!
!  EVALUATION OF W(Z) IN THE OTHER QUADRANTS
!

      IF (YI.LT.0.0) THEN
!
        IF (A) THEN
          U2    = 2*U2
          V2    = 2*V2
        ELSE
          XQUAD =  -XQUAD
!
!
!         THE FOLLOWING IF-STATEMENT PROTECTS 2*EXP(-Z**2)
!         AGAINST OVERFLOW
!
          IF ((YQUAD.GT.RMAXGONI).OR.  &
              (XQUAD.GT.RMAXEXP)) GOTO 100
!
          W1 =  2*DEXP(XQUAD)
          U2  =  W1*DCOS(YQUAD)
          V2  = -W1*DSIN(YQUAD)
        END IF
!
        U = U2 - U
        V = V2 - V
        IF (XI.GT.0.0) V = -V
      ELSE
        IF (XI.LT.0.0) V = -V
      END IF
!
      RETURN
!
  100 FLAG = .TRUE.
      RETURN
!
      END subroutine wofz

end module hammett
