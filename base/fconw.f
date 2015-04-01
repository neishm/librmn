*/* RMNLIB - Library of useful routines for C and FORTRAN programming
* * Copyright (C) 1975-2001  Division de Recherche en Prevision Numerique
* *                          Environnement Canada
* *
* * This library is free software; you can redistribute it and/or
* * modify it under the terms of the GNU Lesser General Public
* * License as published by the Free Software Foundation,
* * version 2.1 of the License.
* *
* * This library is distributed in the hope that it will be useful,
* * but WITHOUT ANY WARRANTY; without even the implied warranty of
* * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* * Lesser General Public License for more details.
* *
* * You should have received a copy of the GNU Lesser General Public
* * License along with this library; if not, write to the
* * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* * Boston, MA 02111-1307, USA.
* */
***S/R FCONW  - MAPS A WINDOW FROM A GIVEN GRID.
*
      SUBROUTINE FCONW (Z ,CINT,SCALE,LI,LJ,IW,JW,LL,MM,MTYPE)
      REAL Z(LI,1)

*
*AUTHOR   - JOHN D. HENDERSON  -  MAR 75
*
*REVISION 001   C. THIBEAULT   -  SEP 79  DOCUMENTATION
*REVISION 002   C. THIBEAULT   -  MAR 83  CONVERSION AU CODE CRAY
*
*LANGUAGE  - fortran
*
*OBJECT(FCONW)
*         - MAPS LL BY MM WINDOW FROM POINT (IW,JW) IN Z(LI,LJ) USING
*           A CUBIC INTERPOLATION.
*
*LIBRARIES
*         - SOURCE RMNSOURCELIB,ID=RMNP       DECK=FCONW
*         - OBJECT RMNLIB,ID=RMNP
*
*USAGE    - CALL FCONW(Z,CINT,SCALE,LI,LJ,IW,JW,LL,MM,MTYPE)
*
*ARGUMENTS
*   IN    - Z    - ARRAY TO BE CONTOURED
*         - CINT  - CONTOUR INTERVAL, FROM 0.  IF CINT .GT. 0.,
*                                     FROM (CINT/2) IF CINT .LT.0.
*                   CINT=0, CAUSES ERROR EXIT
*         - SCALE - SCALE FACTOR USED TO MULTIPLY Z BEFORE CONTOURING.
*         - LI    - X-DIMENSION
*         - LJ    - Y-DIMENSION, IF LJ NEGATIVE, RIGHT AND TOP GRID POINTS
*                   OMITTED FOR STAR GRIDS. MINIMUM VALUES ARE (4,4)
*         - IW    - X-COORDINATE OF BOTTOM LEFT CORNER OF WINDOW IN ARRAY Z
*         - JW    - Y-COORDINATE OF BOTTOM LEFT CORNER OF WINDOW IN ARRAY Z
*         - LL    - WIDTH OF WINDOW
*         - MM    - HEIGHT OF WINDOW. MINIMUM VALUES ARE (3,3). NO WINDOW
*                   EXTENDS OUTSIDE THE RIGHT OR TOP SIDES OF THE GRID
*                   REGARDLESS OF HOW LARGE LL OR MM ARE SET
*         - MTYPE - MAP SCALE CONTROL (ABSOLUTE VALUE USED)
*                   SIGN (+) CONTOURS 6 LINES/INCH
*                   SIGN (-) CONTOURS 8 LINES/INCH
*                 - MTYPE = MAPSCL+MESH
*                 - MAPSCL = 20 FOR GRID POINTS 3/4" APART
*                 - MAPSCL = 30 FOR GRID POINTS 1/2" APART
*                 - IF THE GRID IS 381KM POLAR STEREOGRAPHIC THESE
*                   VALUES RESULT IN 1/20M AND 1/30M SCALE MAPS
*                 - MESH SHRINKS THE MAP SCALE (FROM 1 TO 10 EXCEPT 7)
*                   1=FULL, 2=HALF SIZE, 3=1/3 SIZE, ETC...
*
*NOTES    - ILLEGAL CALL GENERATES ERROR MESSAGE.
*         - MAP UNITS REFER TO A COORDINATE SYSTEM CORNERED ON (IW,JW)
*           IN WHICH ONE INCH EQUALS 1440 UNITS.
*
*-------------------------------------------------------------------------------
*
      INTEGER NPRLIN(130),NABCD(8),NUMBER(10)
      DATA NABCD/1H ,1HA,1H ,1HB,1H ,1HC,1H ,1HD/
      DATA NUMBER/1H0,1H1,1H2,1H3,1H4,1H5,1H6,1H7,1H8,1H9/
      DATA NBLANK,NPLUS,NMINUS,NSTAR/1H ,1H+,1H-,1H*/
      DATA NDPC,NDPL6,NDPL8,NPCL,INCH,INCHAH/144,240,180,125,1440,2160/
*
*-------------------------------------------------------------------------------
*
      ENTRY FCONW2(Z,CINT,SCALE,LI,LJ,IW,JW,LL,MM,MTYPE)
*
*     * DETERMINE THE NUMBER OF PRINTED LINES PER INCH.
*
      MT=IABS(MTYPE)
      IF(MT.EQ.0) RETURN
      NDPL=NDPL6
      IF(MTYPE.LT.0) NDPL=NDPL8
      IF(MTYPE.LT.0) WRITE(6,601)
*
*     * DETERMINE THE MAP SCALE AND THE GRID POINTS TO BE PRINTED.
*     * NDGP = DISTANCE BETWEEN GRID POINTS IN MAP UNITS.
*     * NWST = MAXIMUM WIDTH OF A MAP STRIP IN MAP UNITS.
*     * NPRINT = DISTANCE BETWEEN PRINTED GRID POINTS IN MAP UNITS.
*
      IF(MT.GT.40) GO TO 98
      IF(MT.LE.30) GO TO 11
      NDGP= 720/(MT-30)
      NWST=125*NDPC
      NPRINT=INCH
      GO TO 13
   11 IF(MT.LE.20) GO TO 12
      NDGP=1080/(MT-20)
      NWST=120*NDPC
      NPRINT=INCHAH
      GO TO 13
   12 IF(MT.GT.3) GO TO 98
      NDGP=MT*INCH
      NWST=((125*NDPC)/NDGP)*NDGP
      NPRINT=NDGP
   13 FNDGP=FLOAT(NDGP)
      GDIST=NDGP/FLOAT(INCH)
      IPDIST=NPRINT/FLOAT(NDGP)
*
*     * DEFINE THE WINDOW TO BE MAPPED.
*     * ICMIN,ICMAX = LEFT AND RIGHT SIDES OF WINDOW IN MAP UNITS.
*     * JCMIN,JCMAX = BOTTOM AND TOP EDGES OF WINDOW IN MAP UNITS.
*     * JCNJ = TOP OF THE GRID IN MAP UNITS.
*
      NI=LI
      IF(LJ.LT.0) NI=LI-1
      NJ=IABS(LJ)
      IF(LJ.LT.0) NJ=NJ-1
      L=LL
      IF(IW+L.GT.NI) L=NI-IW
      M=MM
      IF(JW+M.GT.NJ) M=NJ-JW
      IF(NI.LT.4.OR.NJ.LT.4) GO TO 98
      IF( L.LT.3.OR. M.LT.3) GO TO 98
      ICMIN=0
      ICMAX=NDGP*L
      ICMAX=ICMAX-MOD(ICMAX,NDPC)
      JCMIN=0
      JCMAX=NDGP*M
      JCMAX=JCMAX-MOD(JCMAX,NDPL)
      JCNJ=NDGP*(NJ-JW)
*
*     * CALCULATE INTERPOLATION CONSTANTS.
*
      IF(CINT.EQ.0.) GO TO 98
      CSHIFT=0.0
      IF(CINT.LT.0.) CSHIFT=0.5
      CSC=ABS(SCALE/CINT)
      CSC2=CSC/2.
      CSC6=CSC/6.
      SIXTH=1./6.
*
*-----------------------------------------------------------------------
*
*     * MAP STRIP LOOP. RETURN IF LAST STRIP IS FINISHED.
*     * IPCL,IPCR = LEFT AND RIGHT SIDES OF MAP STRIP IN MAP UNITS.
*     * IPNTL = POSITION OF FIRST PRINTED GRID POINT IN MAP UNITS.
*
      IPCR=ICMIN
   15 IPCL=IPCR
      IF(IPCL.GE.ICMAX) GO TO 99
      IPCR=IPCL+NWST
      IF(IPCR.GT.ICMAX) IPCR=ICMAX
      IPNTL=IPCL
      IPNTC=MOD(IPCL,NPRINT)
      IF(IPNTC.NE.0) IPNTL=IPNTL+NPRINT-IPNTC
      WRITE(6,610) CINT,SCALE,GDIST,IPDIST,LI,LJ,IW,JW,LL,MM,MTYPE
*
*     * START OF PRINT LINE LOOP FOR EACH MAP STRIP.
*     * J IDENTIFIES THE LOWER SIDE OF THE INNER INTERPOLATION SQUARE.
*     * Q = DISTANCE OF THE CURRENT ROW FROM ROW J IN GRID UNITS.
*     * JPL = POSITION OF CURRENT PRINT LINE IN MAP UNITS.
*
      JPL=JCMAX
   21 J=JPL/NDGP+JW
      IF(J.GT.NJ-2) J=NJ-2
      IF(J.LT.2)    J=2
      JDIF=JPL-(J-JW)*NDGP
      Q=FLOAT(JDIF)/FNDGP
      QA=CSC6*(-Q*(Q-1.)*(Q-2.))
      QB=CSC2*(   (Q-1.)*(Q+1.)*(Q-2.))
      QC=CSC2*(-Q*(Q+1.)*(Q-2.))
      QD=CSC6*( Q*(Q+1.)*(Q-1.))
*
*     * START OF PRINT CHARACTER LOOP FOR EACH PRINT LINE.
*     * I IDENTIFIES THE LEFT SIDE OF THE INNER INTERPOLATION SQUARE.
*     * P = DISTANCE OF THE CURRENT PRINT CHARACTER FROM I IN MAP UNITS.
*
      ILAST=-1
      NCH=0
      DO 40 IPC=IPCL,IPCR,NDPC
      NCH=NCH+1
      I=IPC/NDGP+IW
      IF(I.GT.NI-2) I=NI-2
      IF(I.LT.2)    I=2
      IDIF=IPC-(I-IW)*NDGP
      P=FLOAT(IDIF)/FNDGP
      IF( I.EQ.ILAST) GO TO 39
      IF(ILAST.GT.0 ) GO TO 38
      ZB=QA*Z(I-1,J-1)+QB*Z(I-1,J)+QC*Z(I-1,J+1)+QD*Z(I-1,J+2)
      ZC=QA*Z(I  ,J-1)+QB*Z(I  ,J)+QC*Z(I  ,J+1)+QD*Z(I  ,J+2)
      ZD=QA*Z(I+1,J-1)+QB*Z(I+1,J)+QC*Z(I+1,J+1)+QD*Z(I+1,J+2)
   38 ZA=ZB
      ZB=ZC
      ZC=ZD
      ZD=QA*Z(I+2,J-1)+QB*Z(I+2,J)+QC*Z(I+2,J+1)+QD*Z(I+2,J+2)
      ILAST=I
   39 CONTINUE
      PA=SIXTH*(-P*(P-1.)*(P-2.))
      PB=  0.5*(   (P-1.)*(P+1.)*(P-2.))
      PC=  0.5*(-P*(P+1.)*(P-2.))
      PD=SIXTH*( P*(P+1.)*(P-1.))
      CONT=PA*ZA+PB*ZB+PC*ZC+PD*ZD + CSHIFT
      NCONT=INT(CONT)
      NCONT=MOD(NCONT,8)+1
      IF(CONT.LT.0.) NCONT=7+NCONT
      NPRLIN(NCH)=NABCD(NCONT)
   40 CONTINUE
*
*     * INSERT GRID POINT VALUES IF THIS IS A GRID ROW TO BE PRINTED.
*     * FLOATING GRID VALUES ARE SCALED, ROUNDED AND CONVERTED TO INTEGE
*     * SIGN AND LOWEST FOUR DIGITS ARE INSERTED INTO NPRLIN.
*
      NCHP=NCH+1
      DO 51 NN=NCHP,130
   51 NPRLIN(NN)=NBLANK
      IF(JPL/NPRINT*NPRINT.NE.JPL) GO TO 57
      K=J
      IF(JPL.EQ.JCNJ ) K=NJ
      IF(JPL.EQ.JCNJ-NDGP) K=NJ-1
      IF(JPL.EQ.0)     K=JW
      NPRLIN(1)=NSTAR
      NPRLIN(NCH)=NSTAR
      DO 55 IPNT=IPNTL,IPCR,NPRINT
      I=IPNT/NDGP+IW
      NCH=(IPNT-IPCL)/NDPC+6
      P=Z(I,K)*SCALE
      IQ=INT(ABS(P)+0.5)
      NPRLIN(NCH-5)=NPLUS
      IF(P.LT.0.) NPRLIN(NCH-5)=NMINUS
      DO 54 NN=1,4
      IQ10=IQ/10
      NPRLIN(NCH-NN)=NUMBER(IQ-IQ10*10+1)
   54 IQ=IQ10
   55 CONTINUE
*
*     * PRINT ONE LINE. IF NOT END OF STRIP GO BACK TO PRINT LINE LOOP
*     *  AT STATEMENT 21. OTHERWISE START NEW STRIP AT STATEMENT 15.
*
   57 WRITE(6,620) NPRLIN
      JPL=JPL-NDPL
      IF(JPL.GE.JCMIN) GO TO 21
      GO TO 15
*
   98 WRITE(6,698) CINT,SCALE,LI,LJ,IW,JW,LL,MM,MTYPE
   99 IF(MTYPE.LT.0) WRITE(6,699)
      RETURN
*
*-----------------------------------------------------------------------
*
  601 FORMAT(1HT)
  610 FORMAT(1H1,5X,8HCONTOUR=,1PE11.4,5X,6HSCALE=,E11.4,5X,5HGRID=,
     1       0PF7.4,21H INCHES   PRINT EVERY,I3,5X,6I4,I6//)
  620 FORMAT(1H ,130A1)


  698 FORMAT(23H ILLEGAL CALL TO FCONW ,1P2E14.4,7I6)
  699 FORMAT(1HS)
      END