
fn getFilesRecursive root ptrn: "*.max" = (
        local dd = getDirectories (root + "/*")
        local ff = getFiles (root + "/" + ptrn)
        for i in dd do join ff (getFilesRecursive i ptrn: ptrn)
        
        return ff
    )

fn isAllTexturesPresent f o = (
		local ignorePtrn = #(
			@"*\UV_Checker.*",
			@"*\*.hdc",
			@"*\*.cube"
		) 
		local out = #()
		
		local files = getFilesRecursive o ptrn: "*.*"
		local names = for i in files collect filenameFromPath i
		
		local d = getMAXFileAssetMetadata f
		print d
		for i in d where i != undefined and i.type == #bitmap and i.filename != undefined and i.filename != "" do (		
			local isContinue = false
			
			local n = filenameFromPath i.filename
			
			for j in ignorePtrn do (
				if (MatchPattern i.filename pattern: j) do isContinue = true
			)
			
			if (isContinue) do continue
			
			local id = findItem names n
			
			if (id == 0) do (
				appendIfUnique out i.filename
			)
		)
		
		return out
	)

	
	
f = @"BARAZZA_SET_18_3dsMax_2013_1.max"	
o = @"C:\temp\GC\great-catalog-3220\4072\1252-62585fb2261e5\"	
isAllTexturesPresent (o + f) o