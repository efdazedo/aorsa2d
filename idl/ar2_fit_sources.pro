pro ar2_fit_sources, $
    FitThis = FitThis, $
    WithTheseFiles = WithTheseFiles, $
	CoeffsOut_r = CoeffsOut_r, $ ; [NRHS,nSpec]
	CoeffsOut_t = CoeffsOut_t, $ ; [NRHS,nSpec]
	CoeffsOut_z = CoeffsOut_z, $ ; [NRHS,nSpec]
    TwoDim = TwoDim, $
    NRHS = NRHS, $
    FitLayer = FitLayer

	; 0 = r
	; 1 = t
	; 2 = z

	DataFiles = file_search(WithTheseFiles+'/output/solution*.nc')
	sFitMe = FitThis
    nSpecies = n_elements(sFitMe.jP_r[0,0,*])

	if(not keyword_set(NRHS))then NRHS = n_elements(DataFiles)

    ; Determine which points lay in the fit layer

    iiFitThese = where(sFitMe.r ge FitLayer[0] and sFitMe.r le FitLayer[1], iiFitTheseCnt)
    if iiFitTheseCnt le 0 then begin
        print, 'Error: no points to fit within FitLayer'
        stop
    endif

    N = iiFitTheseCnt

    ; Build fit martix A and solve for each component seperately.
    ; Could do each species seperately too I guess.

	amat = complexarr(N,NRHS)
    CoeffsOut_r = ComplexArr(NRHS,nSpecies)
    CoeffsOut_t = ComplexArr(NRHS,nSpecies)
    CoeffsOut_z = ComplexArr(NRHS,nSpecies)

    ComponentArray = [0,1,2]

for spec = 0, nSpecies-1 do begin
	print, 'Species: ', spec
	print, '----------------'

    foreach component, ComponentArray do begin
		print, 'Component: ', component
        c = 0

	    for rhs=0,NRHS-1 do begin

            s = ar2_read_solution (WithTheseFiles, rhs+1)

			; Get basis functions at fit locations ...

			if component eq 0 then thisJp_re = interpol(real_part(s.jP_r[*,0,spec]),s.r,sFitMe.r[iiFitThese],/spline)
			if component eq 1 then thisJp_re = interpol(real_part(s.jP_t[*,0,spec]),s.r,sFitMe.r[iiFitThese],/spline)
			if component eq 2 then thisJp_re = interpol(real_part(s.jP_z[*,0,spec]),s.r,sFitMe.r[iiFitThese],/spline)

			if component eq 0 then thisJp_im = interpol(imaginary(s.jP_r[*,0,spec]),s.r,sFitMe.r[iiFitThese],/spline)
			if component eq 1 then thisJp_im = interpol(imaginary(s.jP_t[*,0,spec]),s.r,sFitMe.r[iiFitThese],/spline)
			if component eq 2 then thisJp_im = interpol(imaginary(s.jP_z[*,0,spec]),s.r,sFitMe.r[iiFitThese],/spline)

            aMat[*,rhs] = complex(thisJp_re,thisJp_im)

	    endfor

	    help, amat

        if component eq 0 then b = sFitMe.jP_r[iiFitThese,0,spec]
        if component eq 1 then b = sFitMe.jP_t[iiFitThese,0,spec]
        if component eq 2 then b = sFitMe.jP_z[iiFitThese,0,spec]

	    coeffs = LA_LEAST_SQUARES(transpose(amat),b, status=stat,method=3,residual=residual)
		if stat ne 0 then stop
       	print, coeffs 

        if component eq 0 then data = sFitMe.jP_r[iiFitThese,0,spec]
        if component eq 1 then data = sFitMe.jP_t[iiFitThese,0,spec]
        if component eq 2 then data = sFitMe.jP_z[iiFitThese,0,spec]

		;fit = transpose(amat)##coeffs
		;p=plot(sFitMe.r[iiFitThese],data,symbol="o",layout=[1,2,1],title="Fit vs Data")
		;p=plot(sFitMe.r[iiFitThese],fit,thick=2,/over)
		;p=plot(sFitMe.r[iiFitThese],imaginary(data),color="red",/over)
		;p=plot(sFitMe.r[iiFitThese],imaginary(fit),color="red",/over,thick=2)
		;p=plot(real_part(coeffs),layout=[1,2,2],title="Coeffs",/current)
		;p=plot(imaginary(coeffs),color="red",/over)
		;stop

        if component eq 0 then CoeffsOut_r[*,spec] = coeffs
        if component eq 1 then CoeffsOut_t[*,spec] = coeffs
        if component eq 2 then CoeffsOut_z[*,spec] = coeffs

    endforeach

endfor

    ; Create the "perFileList" coefficient list


        ;p=plot(Coeffs_R,layout=[1,4,1],dimension=[600,600],title='Coeffs R')
    ;p=plot(imaginary(Coeffs_R),/over,color='b')
    ;p=plot(Coeffs_T,layout=[1,4,2],/current,title='Coeffs T')
    ;p=plot(imaginary(Coeffs_T),/over,color='b')
    ;p=plot(Coeffs_Z,layout=[1,4,3],/current,title='Coeffs Z')
    ;p=plot(imaginary(Coeffs_Z),/over,color='b')
    ;p=plot(CoeffsOut,layout=[1,4,4],/current,title='Coeffs All')
    ;p=plot(imaginary(CoeffsOut),/over,color='b')


    if keyword_set(TwoDim) then begin

        x = r_data_1D
        y = z_data_1D

        nLevs = 20
        ScaleFac = 0.3
        scale = max(abs([jr_data]))*ScaleFac
        dimensions = [600,600]

        ThisField = reform(jr_data,nR_data,nZ_data)

		levels = fIndGen(nLevs)/(nLevs-1)*scale
		colors = reverse(bytScl(levels, top=253)+1)

        title = 'Re(Data)'
		PlotField = (real_part(thisField)<max(levels))>min(-levels)
		c = contour ( PlotField, x, y, c_value=levels, rgb_indices=colors, rgb_table=3, /fill, $
            aspect_ratio=1.0, layout=[2,2,1], dimensions=dimensions, title=title )
		c = contour ( -PlotField, x, y, c_value=levels, rgb_indices=colors, rgb_table=1, /fill,/over )
        p = plot( CurrentSource_r, CurrentSource_z, /over, symbol = "s", lineStyle='none' )

        title = 'Im(Data)'
		PlotField = (imaginary(thisField)<max(levels))>min(-levels)
		c = contour ( PlotField, x, y, c_value=levels, rgb_indices=colors, rgb_table=3, /fill, $
            aspect_ratio=1.0, layout=[2,2,2], /current, title=title )
		c = contour ( -PlotField, x, y, c_value=levels, rgb_indices=colors, rgb_table=1, /fill,/over )
        p = plot( CurrentSource_r, CurrentSource_z, /over, symbol = "s", lineStyle='none' )

        ThisField = FitR_2D 

        title = 'Re(Fit)'
 		PlotField = (real_part(thisField)<max(levels))>min(-levels)
		c = contour ( PlotField, x, y, c_value=levels, rgb_indices=colors, rgb_table=3, /fill, $
            aspect_ratio=1.0, layout=[2,2,3], /current, title=title )
		c = contour ( -PlotField, x, y, c_value=levels, rgb_indices=colors, rgb_table=1, /fill,/over )
        p = plot( CurrentSource_r, CurrentSource_z, /over, symbol = "s", lineStyle='none' )

        title = 'Im(Fit)'
		PlotField = (imaginary(thisField)<max(levels))>min(-levels)
		c = contour ( PlotField, x, y, c_value=levels, rgb_indices=colors, rgb_table=3, /fill, $
            aspect_ratio=1.0, layout=[2,2,4], /current, title=title )
		c = contour ( -PlotField, x, y, c_value=levels, rgb_indices=colors, rgb_table=1, /fill,/over )
        p = plot( CurrentSource_r, CurrentSource_z, /over, symbol = "s", lineStyle='none' )

    endif else begin

    endelse

end
