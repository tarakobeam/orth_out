*! version 2.1.1 Joe Long 2dec2013
cap program drop orth_out
program orth_out, rclass
	version 12
	syntax varlist [using] [if], BY(varlist) [replace] ///
		[SHEET(string) SHEETREPlace BDec(numlist) COMPare count]  ///
		[NOLAbel ARMLAbel(string) VARLAbel(string asis) NUMLAbel] ///
		[COLNUM Title(string) NOTEs(string)] [Ftest] [overall] ///
		[PROPortion] [SEmean] [COVARiates(varlist)] ///
		[INTERACTion] [Reverse] [APPEND] 
		
	qui{
		preserve
		if "`append'" != ""{
			tempname B 
			mat `B' = r(matrix)
			loc Brow `:rownames `B''
			loc Bcol `:colnames `B''
			loc Breq `:roweq `B', q'
			loc Bceq "`:coleq `B', q'"
		}
		if `"`if'"' != ""{
			keep `if'
		}
		loc ntreat: word count `by'
		forvalues n = 1/`ntreat' {
			loc word: word `n' of `by'
			loc byrep "`word' `byrep'"
		}
		loc by `byrep'
		if `ntreat' > 1 {
			tempvar treatment_type
			egen `treatment_type' = group(`by')
		}
		else {
			levelsof `by', local(arms)
			loc n 0
			loc vallab: val lab `by'
			foreach val of loc arms {
				loc ++n
				if "`vallab'" != ""{
					loc cname: lab `vallab' `val'
				}
				else{
					loc cname: lab `by' `val'
				}
				loc cnames "`cnames' "`cname'""
			}

			loc ntreat : word count `arms'
			
			loc n 0
			foreach val of loc arms {
				loc ++n
				tempvar treatarm`n'
				gen `treatarm`n'' = `by' == `val'
			}

			tempvar treatment_type
			gen `:type `by'' `treatment_type' = `by'
			loc by ""
			forvalues m = 1/`ntreat'{
				loc by "`by' `treatarm`m''"
			}
		}

		loc varcount: word count `varlist'
		loc by2 `by'
		if "`compare'" != ""{
			loc m = (`ntreat'^2+`ntreat')/2
		}
		else{
			loc m = `ntreat'
		}
		
		if "`interaction'" != ""{
			loc interaction 
			foreach var1 of local covariates{
				foreach var2 of local by{
					tempvar `var1'X`var2'
					gen ``var1'X`var2'' = `var1' * `var2'
					loc interaction `interaction' ``var1'X`var2''
				}
			}
		}
		
		loc count 	= 1 - mi("`count'")
		loc ftest 	= 1 - mi("`ftest'")
		loc overall	= 1 - mi("`overall'")
		loc prop    = 1 - mi("`proportion'")
		loc sterr	= 2 - mi("`semean'")
		loc interact= 1 - mi("`interaction'")
		loc reverse = 1 - mi("`reverse'")
		
		tempname A
		mat `A' = J(`sterr'*`varcount'+`count'+`prop', `m'+`reverse'+`overall'+`ftest', .)
		loc r 0
		foreach var in `varlist' {
			loc ++r

			tabstat `var' , by(`treatment_type') stats(mean `semean') save
			forvalues n = 1/`ntreat'{
				mat `A'[`r',`n'] = r(Stat`n')
			}
			if `overall'{
				mat `A'[`r', `ntreat'+1] = r(StatTotal)
			}
			loc j = `ntreat' + `overall'
			if "`compare'" != ""{
				forvalues n = 1/`ntreat'{
					gettoken var1 by: by
					foreach var2 of loc by{
						reg `var' `var1' if (`var1'==1 | `var2'==1)
						loc ++j
						loc b = _b[`var1']
						loc se = _se[`var1']
						mat `A'[`r',`j'] = `b'
						if "`semean'" != ""{
							mat `A'[`r'+1,`j'] = `se'
						}
					}
				}
			}
			loc by `by2'
			if `reverse'{
				reg `:word 1 of `by'' `var' `covariates' `interaction', noheader
				mat `A'[`r', `m'+`overall'+`reverse'] = _b[`var']
				if `sterr' == 2{
					mat `A'[`r'+1, `m'+`overall'+`reverse'] = _se[`var']
				}
			}
			if `ftest'{
				qui reg `var' `by' `covariates' `interaction', noheader 
				mat `A'[`r', `m'+`overall'+`reverse'+`ftest'] = Ftail(e(df_m), e(df_r), e(F))
			}
			loc r = `r' + (`sterr' - 1)
		}
		
		if `count' | `prop' {
			tempvar N
			gen `N' = 1
			tabstat `N', by(`treatment_type') stats(n) save
			forvalues n = 1/`ntreat'{
				if `count' {
					mat `A'[`sterr'*`varcount'+`count',`n'] = r(Stat`n')
				}
				if `prop' {
					mat `A'[`sterr'*`varcount'+`count'+`prop',`n'] = r(StatTotal)
					mat `A'[`sterr'*`varcount'+`count'+`prop',`n'] = `A'[`sterr'*`varcount'+`count',`n']/`A'[`sterr'*`varcount'+`count'+`prop',`n']
				}
			}
			if `overall'{
				mat `A'[`sterr'*`varcount'+`count',`ntreat'+1] = r(StatTotal)
				if `prop'{					
					mat `A'[`sterr'*`varcount'+`count'+`prop',`ntreat'+1] = 1
				}		
			}
		}
		
		if "`append'" != ""{
			tempname C
			mat `C' = J(1, `m'+`reverse'+`overall'+`ftest', .)
			mat `A' = `B' \ `C' \ `A' 
		}
		if "`nolabel'" == "" {
			if `"`varlabel'"' != ""{
				loc varlist2 `varlist'
				forvalues n = 1/`varcount' {
					gettoken var varlist: varlist
					loc lab`n': word `n' of `varlabel'
					la var `var' "`lab`n''"
				}
			}
			foreach var of loc varlist{
				loc rname: var la `var'
				if "`rname'" == ""{
					loc rname `var'
				}
				if "`semean'"!=""{
					loc rnames "`rnames' "`rname'" " ""
				}
				else {
					loc rnames "`rnames' "`rname'""
				}
			}
			if `count' {
				loc rnames "`rnames' "N""
			}
			if `prop' {
				loc rnames "`rnames' "Proportion""
			}
			if "`armlabel'"!=""{
				loc ccount: word count `armlabel'
					if `ccount' == `ntreat'{
						loc cnames `armlabel'
					}
			}
			else if "`numlabel'" != ""{
				forvalues n = 1/`ntreat'{
					loc cnames "`cnames' (`n')"
				}
			}
			else if "`arms'" == ""{
				foreach var of loc by{
					loc cname: var lab `var'
					if "`cname'" == ""{
						loc cname "`var'"
					}
					loc cnames ""`cname'" `cnames'"
				}
			}
			forvalues n = 1/`ntreat'{
				loc num "`num' `n'"
			}
			if `overall'{
				loc cnames "`cnames' "Overall""
			}
			if "`compare'" != ""{
				forvalues n = 1/`ntreat'{
				gettoken num1 num: num
					foreach num2 of loc num{
						loc cnames2 "`cnames2' "(`num1') vs. (`num2')""
					}
				}
			}
			loc cnames "`cnames' `cnames2'"
			if `reverse'{
				if `sterr' == 2 {
					loc standard "s. & s.e."
				}
				else {
					loc standard "icients"
				}
				loc cnames "`cnames' "Coeff`standard', treatment as dep. variable""
			}

			if `ftest'{
				loc cnames "`cnames' "p-value from joint orthogonality test of treatment arms""
			}
		}
		else {
			loc rnames ""
			loc cnames ""
		}
		if "`colnum'" != "" {
			loc column ""
			loc p = `m'+`reverse'+`overall'+`ftest'
			forvalues n = 1/`p'{
				loc column "`column' "(`n')""
			}
		}
		if "`bdec'"==""{
			loc bdec = 3
		}
		
		if "`title'" == ""{
			loc title "Orthogonality Table"
		}
		forvalues n = 1/`varcount'{
			loc req "`req' mean"
			if `sterr' == 2{
				loc req "`req' se"
			}
		}
		if `count'{
			loc req "`req' _"
		}
		if `prop'{
			loc req "`req' _"
		}
		if "`append'" != ""{
			loc rnames ""`Breq'" " " `rnames'"
			loc req    "`Brow' " " `req'"
		}
		if "`using'" != ""{
			clear
			svmat `A'
			tempvar n
			tostring _all, replace force format(%12.`bdec'f)
			gen `n' = _n + 2
			tempvar B0
			gen `B0' = ""
			if "`append'" != ""{
				replace `n' = -1 if `n' == rowsof(`B') + `count' + `prop' + 1
				replace `n' = `n' - 1 if `n' >= rowsof(`B') + `count' + `prop' + 1
			}
			if `sterr' == 2{
				foreach var of varlist `A'*{
					replace `var' = "(" + `var' + ")" if `var' != "." & mod(`n', 2) == 0 
				}
			}
			if "`append'" != ""{
				replace `n' = `n' + 1 if `n' >= rowsof(`B') + `count' + `prop' + 1
				replace `n' = rowsof(`B') + `count' + `prop' + 1 if `n' == -1
			}
			loc p = 2
			foreach name in `rnames'{
				loc ++p
				replace `B0' = "`name'" if `n' == `p' & "`name'" != "_"
			}

			d, s
			loc N = `r(N)' + 1
			set obs `N'
			replace `n' = 1 if `n' == .
			sort `n'

			forvalues m = 1/`:word count `cnames''{
				replace `A'`m' = "`:word `m' of `cnames''" if `n' == 1
			}
			if "`append'" != ""{
				forvalues m = 1/`:word count `Bceq''{
					replace `A'`m' = "`:word `m' of `Bceq''" if `n' == rowsof(`B') + `count' + `prop' + 1
				}
			}
			if "`colnum'" != ""{	
				loc N = `N' + 1
				set obs `N'
				replace `n' = 2 if `n' == .
				sort `n'
				forvalues m = 1/`:word count `column''{
					replace `A'`m' = "`:word `m' of `column''" if `n' == 2
				}
			}
			if "`title'" != ""{
				loc N = `N' + 1
				set obs `N' 
				replace `n' = 0 if `n' == . 
				sort `n' 
				replace `B0' = "`title'" if `n' == 0
			}
			if "`notes'" != ""{
				loc N = `N' + 1
				set obs `N' 
				sort `n' 
				replace `B0' = "`notes'" if mi(`n')
			}
			loc note = 1 - mi("`notes'")
			foreach var of varlist `A'*{
				if `count'{
					loc normal = `bdec' != 0
					replace `var' = substr(`var', 1, length(`var')-`bdec'-`normal') if `B0' == "N" & "`var'" != "`B0'"
				}
				if `prop'{
					replace `var' = substr(`var', 2, length(`var')-2) if `B0' == "Proportion" & "`var'" != "`B0'"					
				}
			}
			ds, has(type string)
			foreach var of varlist `r(varlist)'{
				replace `var' = "" if `var' == "."
			}
			order `B0', first
			drop `n'
			noi export excel _all `using', `replace' sheet("`sheet'") `sheetmodify' `sheetreplace'
		}
		if `"`column'"' == ""{
			forvalues n = 1/`=`m'+`reverse'+`overall'+`ftest''{
				loc column "`column' _"
			}
		}
		mat rown   `A' = `req'	
		mat coln   `A' = `column'
		mat roweq  `A' = `rnames'
		mat coleq  `A' = `cnames'
		noi mat li `A', noheader format(%12.`bdec'f)
		
		return loc rnames `rnames' 
		return loc cnames `cnames'
		return loc title  `title'
		return matrix matrix `A'
	}
end
