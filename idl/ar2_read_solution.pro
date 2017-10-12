function ar2_read_solution, runFolderName, RHS
   
    @constants

	ar2Input = ar2_read_namelist( RunFolderName = RunFolderName)
	ThisGridNo = 1
	GridNoStr = string(ThisGridNo,format='(i3.3)')
	ThisNPhi = ar2Input['nPhi']
    ThisRHS = RHS
	nPhiStr = string(ThisNPhi,format='(i+7.6)')
	rhsStr = string(ThisRHS,format='(i6.6)')

	SolutionFile = expand_path(RunFolderName)+'/output/solution_'+GridNoStr+'_'+nPhiStr+'_'+rhsStr+'.nc'
	RunDataFile = expand_path(RunFolderName)+'/output/runData_'+GridNoStr+'_'+nPhiStr+'_'+rhsStr+'.nc'

	cdfId = ncdf_open ( RunDataFile, /noWrite ) 
		nCdf_varGet, cdfId, 'nPhi', nPhi 
		nCdf_varGet, cdfId, 'freq', freq 
		nCdf_varGet, cdfId, 'capR', x 
		nCdf_varGet, cdfId, 'y', y 
		nCdf_varGet, cdfId, 'jr_re', jr_re 
		nCdf_varGet, cdfId, 'jr_im', jr_im 
		nCdf_varGet, cdfId, 'jt_re', jt_re 
		nCdf_varGet, cdfId, 'jt_im', jt_im 
		nCdf_varGet, cdfId, 'jz_re', jz_re 
		nCdf_varGet, cdfId, 'jz_im', jz_im 
        nCdf_varGet, cdfId, 'nZ_1D', nz_1D
	ncdf_close, cdfId


	cdfId = ncdf_open ( SolutionFile, /noWrite ) 

		nCdf_varGet, cdfId, 'r', r
		nCdf_varGet, cdfId, 'z', z
		nCdf_varGet, cdfId, 'nPhi', nPhi 
		nCdf_varGet, cdfId, 'freq', freq 
	
		nCdf_varGet, cdfId, 'ealpha_re', ealpha_re 
		ealpha_re = temporary(ealpha_re[*,*])
		nCdf_varGet, cdfId, 'ebeta_re', ebeta_re 
		ebeta_re = temporary(ebeta_re[*,*])
		nCdf_varGet, cdfId, 'eB_re', eB_re 
		eb_re = temporary(eb_re[*,*])

		nCdf_varGet, cdfId, 'ealpha_im', ealpha_im 
		ealpha_im = temporary(ealpha_im[*,*])
		nCdf_varGet, cdfId, 'ebeta_im', ebeta_im 
		ebeta_im = temporary(ebeta_im[*,*])
		nCdf_varGet, cdfId, 'eB_im', eB_im 
		eb_im = temporary(eb_im[*,*])

		nCdf_varGet, cdfId, 'ealphak_re', ealphak_re 
		ealphak_re = temporary(ealphak_re[*,*])
		nCdf_varGet, cdfId, 'ebetak_re', ebetak_re 
		ebetak_re = temporary(ebetak_re[*,*])
		nCdf_varGet, cdfId, 'eBk_re', eBk_re 
		ebk_re = temporary(ebk_re[*,*])

		nCdf_varGet, cdfId, 'ealphak_im', ealphak_im 
		ealphak_im = temporary(ealphak_im[*,*])
		nCdf_varGet, cdfId, 'ebetak_im', ebetak_im 
		ebetak_im = temporary(ebetak_im[*,*])
		nCdf_varGet, cdfId, 'eBk_im', eBk_im 
		ebk_im = temporary(ebk_im[*,*])

		nCdf_varGet, cdfId, 'er_re', er_re 
		er_re = temporary(er_re[*,*])
		nCdf_varGet, cdfId, 'et_re', et_re 
		et_re = temporary(et_re[*,*])
		nCdf_varGet, cdfId, 'ez_re', ez_re 
		ez_re = temporary(ez_re[*,*])

		nCdf_varGet, cdfId, 'er_im', er_im 
		er_im = temporary(er_im[*,*])
		nCdf_varGet, cdfId, 'et_im', et_im 
		et_im = temporary(et_im[*,*])
		nCdf_varGet, cdfId, 'ez_im', ez_im 
		ez_im = temporary(ez_im[*,*])

		nCdf_varGet, cdfId, 'jalpha_re', jalpha_re 
		nCdf_varGet, cdfId, 'jbeta_re', jbeta_re 
		nCdf_varGet, cdfId, 'jB_re', jB_re 

		nCdf_varGet, cdfId, 'jalpha_im', jalpha_im 
		nCdf_varGet, cdfId, 'jbeta_im', jbeta_im 
		nCdf_varGet, cdfId, 'jB_im', jB_im 

		nCdf_varGet, cdfId, 'jP_r_re', jPr_re 
		nCdf_varGet, cdfId, 'jP_t_re', jPt_re 
		nCdf_varGet, cdfId, 'jP_z_re', jPz_re 

		nCdf_varGet, cdfId, 'jP_r_im', jPr_im 
		nCdf_varGet, cdfId, 'jP_t_im', jPt_im 
		nCdf_varGet, cdfId, 'jP_z_im', jPz_im 

		nCdf_varGet, cdfId, 'jouleHeating', jouleHeating 

		ealpha	= complex ( ealpha_re, ealpha_im )
		ebeta	= complex ( ebeta_re, ebeta_im )
		eb	= complex ( eb_re, eb_im )

		ealphak	= complex ( ealphak_re, ealphak_im )
		ebetak	= complex ( ebetak_re, ebetak_im )
		ebk	= complex ( ebk_re, ebk_im )

		e_r	= complex ( er_re, er_im )
		e_t	= complex ( et_re, et_im )
		e_z	= complex ( ez_re, ez_im )

		jP_r	= complex ( jPr_re, jPr_im )
		jP_t	= complex ( jPt_re, jPt_im )
		jP_z	= complex ( jPz_re, jPz_im )

		jPAlpha = complex ( jAlpha_re, jAlpha_im )
		jPBeta = complex ( jBeta_re, jBeta_im )
		jPB = complex ( jB_re, jB_im )

        sig = 0
        kr = 0
        kz = 0
        fileHasSigmas = ncdf_varId(cdfId,'sig11_re')
        if fileHasSigmas ne -1 then begin

            nCdf_varGet, cdfId, 'kr', kr 
            nCdf_varGet, cdfId, 'kz', kz 

            nCdf_varGet, cdfId, 'sig11_re', sig11_re
            nCdf_varGet, cdfId, 'sig11_im', sig11_im
            nCdf_varGet, cdfId, 'sig12_re', sig12_re
            nCdf_varGet, cdfId, 'sig12_im', sig12_im
            nCdf_varGet, cdfId, 'sig13_re', sig13_re
            nCdf_varGet, cdfId, 'sig13_im', sig13_im

            nCdf_varGet, cdfId, 'sig21_re', sig21_re
            nCdf_varGet, cdfId, 'sig21_im', sig21_im
            nCdf_varGet, cdfId, 'sig22_re', sig22_re
            nCdf_varGet, cdfId, 'sig22_im', sig22_im
            nCdf_varGet, cdfId, 'sig23_re', sig23_re
            nCdf_varGet, cdfId, 'sig23_im', sig23_im

            nCdf_varGet, cdfId, 'sig31_re', sig31_re
            nCdf_varGet, cdfId, 'sig31_im', sig31_im
            nCdf_varGet, cdfId, 'sig32_re', sig32_re
            nCdf_varGet, cdfId, 'sig32_im', sig32_im
            nCdf_varGet, cdfId, 'sig33_re', sig33_re
            nCdf_varGet, cdfId, 'sig33_im', sig33_im
 
            sig11 = complex(sig11_re,sig11_im) 
            sig12 = complex(sig12_re,sig12_im) 
            sig13 = complex(sig13_re,sig13_im) 

            sig21 = complex(sig21_re,sig21_im) 
            sig22 = complex(sig22_re,sig22_im) 
            sig23 = complex(sig23_re,sig23_im) 

            sig31 = complex(sig31_re,sig31_im) 
            sig32 = complex(sig32_re,sig32_im) 
            sig33 = complex(sig33_re,sig33_im) 

            _nS = n_elements(sig11[0,0,*])
            _nX = n_elements(sig11[*,0,0])
            _nN = n_elements(sig11[0,*,0])

            sig = complexArr(3,3,_nX,_nN,_nS)

            for s=0,_nS-1 do begin
                sig[0,0,*,*,s] = (sig11[*,*,s])[*]
                sig[0,1,*,*,s] = (sig12[*,*,s])[*]
                sig[0,2,*,*,s] = (sig13[*,*,s])[*]

                sig[1,0,*,*,s] = (sig21[*,*,s])[*]
                sig[1,1,*,*,s] = (sig22[*,*,s])[*]
                sig[1,2,*,*,s] = (sig23[*,*,s])[*]

                sig[2,0,*,*,s] = (sig31[*,*,s])[*]
                sig[2,1,*,*,s] = (sig32[*,*,s])[*]
                sig[2,2,*,*,s] = (sig33[*,*,s])[*]
            endfor

        endif

	ncdf_close, cdfId

	x = r
	y = z
	nx = n_elements(r)
	ny = n_elements(z)
	x2D	= rebin ( r, nX, nY )
	if nY gt 1 then begin
		y2D = transpose(rebin ( z, nY, nX ))
	endif else begin
		y2D = fltArr(1)+z
	endelse

    if nY gt 1 then begin
            print, 'NOT CALCULATING B1 ... yet to implement in 2-D'
    endif else begin

        ; Calculate the H vector & the Poynting vector

         
        h_r = complexArr(nX)
        h_t = complexArr(nX)
        h_z = complexArr(nX)

        k_z = nZ_1D*0 ; this is NOT right, fix for non-zero nZ

        dr = r[1]-r[0]
        for i=2,nX-3 do begin

            dEz_dr = (1.0/12.0*e_z[i-2] - 2.0/3.0*e_z[i-1]$
                    +2.0/3.0*e_z[i+1] - 1.0/12.0*e_z[i+2])/dr
            drEt_dr = (1.0/12.0*r[i-2]*e_t[i-2] - 2.0/3.0*r[i-1]*e_t[i-1]$
                    +2.0/3.0*r[i+1]*e_t[i+1] - 1.0/12.0*r[i+2]*e_t[i+2])/dr

            h_r[i] = -_ii*k_z*e_t[i] + _ii*nPhi*e_z[i]/r[i]
            h_t[i] = _ii*k_z*e_r[i] - dEz_dr 
            h_z[i] = (-_ii*nPhi*e_r[i] + drEt_dr )/r[i]

        endfor

        wrf = 2 * !pi * freq
        
        h_r = h_r / (_ii*wRF*_u0)
        h_t = h_t / (_ii*wRF*_u0)
        h_z = h_z / (_ii*wRF*_u0)

        b_r = _u0 * h_r
        b_t = _u0 * h_t
        b_z = _u0 * h_z

    endelse

    solution = { $
                r: r, $
                z: z, $
                x: x, $
                y: y, $
                x2d: x2d, $
                y2d: y2d, $
                jPAlp: jPAlpha, $
                jPBet: jPBeta, $
                jPPrl: jPB, $
                jP_r: jP_r, $
                jP_t: jP_t, $
                jP_z: jP_z, $
                e_r: e_r, $
                e_t: e_t, $
                e_z: e_z, $
                ealpk: ealphak, $
                ebetk: ebetak, $
                eprlk: ebk, $
                ealp: ealpha, $
                ebet: ebeta, $
                eprl: eb, $
                b1_r: b_r, $
                b1_t: b_t, $
                b1_z: b_z, $
                jA_r: complex(jr_re,jr_im), $
                jA_t: complex(jt_re,jt_im), $
                jA_z: complex(jz_re,jz_im), $
                sig: sig, $
                kr : kr, $
                kz : kz }

    return, solution

end



