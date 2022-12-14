/*  
[INFO] 
NAME = GC Batch Repack
VERSION = 1.1.4
AUTHOR = Vasyl Lukianenko 
DEV = https://3dground.net
HELP = 
CLIENT = Great Catalog
[ABOUT]
Processes archives and repacks them, eliminating the problem of Root CA=

[1.0.0]
*Initial release =

[1.0.1]
+Added: setVRaySilentMode=

[1.0.2]
*Test updater=

[1.0.3]
+ Added: Functionality for Repack only selected items=

[1.0.4]
+Added: Installer=

[1.0.5]
+Added: Preview remover=
+Added: Use original arhcive name for *.max files=
+Added: Archive normalizer (move all files from subdir to root)=

[1.0.6]
-BugFix: robocopy.exe for remote machine execution=

[1.0.7]
+Added: Check missing textures=
+Added: Filter max files for ModelPacker versions=

[1.0.8]
+Added: Detect render by object materials=
+Added: Remove old Model Packer scenes without GC=
+Added: Original-Scene prefix for user scenes=
*Changed: Improved texture detection=

[1.0.9]
*Changed: Small improvements=

[1.1.0]
*Changed: Small improvements=


[1.1.1]
*Changed: Ingonre archives with GC- prefix=

[1.1.2]
+ Added: Checkbox for search only Missing Textures=
+ Added: Log to listener for only Missing Textures=
- BugFix: Minor fixes=

[1.1.3]
- BugFix: Small fixes=

[1.1.4]
* Changed: Logic of thread arhvives with enabled option Missing Textures=

[SCRIPT]
*/

struct zipSimpleWrapper (
	currentPath = getFileNamePath (getThisScriptFileName()),
		
	fn extract f o = (
		if (f == undefined or not doesFileExist f) do return false
        if (getFilenameType f != ".zip") do return false
		local args = f + ";" + o
		args = substituteString args "/" @"\"
		
		local cmd = "extract.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir  
	), 
	
	fn archivate n o = (
		if (not doesDirectoryExist o) do return false
		
		local args = n + ";" + o
		args = substituteString args "/" @"\"
		
		local cmd = "archivate.bat \"" +  args + "\""
		
		local curDir = sysInfo.currentDir
		sysInfo.currentDir = currentPath
		
		hiddenDosCommand cmd exitCode: &exitcode donotwait: false
		
		sysInfo.currentDir = curDir
	)	
)

struct settingsWrapper (
    pth = getFilenamePath (getThisScriptFilename()),
    settingsFile = pth + @"settings.ini",
    fn s k v ss: "SETTINGS" = (
        setINISetting settingsFile ss k (v as string)
    ),
    fn g k type: #string  ss: "SETTINGS" = (
        local s = getINISetting settingsFile ss k
        case type of (
            #int: return s as integer
            #float: return s as float
            #bool: if s == "true" or s.count < 1 then true else false
            #bool_not: if s == "true" then true else false
            
            default: return s
        )
    ),
    fn a ss: "SETTINGS" type: #string = (
        local s = getINISetting settingsFile ss
        local o = #()
        
        for k in s do (
            local v = g k ss: ss type: type
            append o #(k, v)
        )
        
        return o
    ),
    fn d k ss: "SETTINGS" = (
        delIniSetting settingsFile ss k
    )
)

'@' = settingsWrapper()

fn boost = (
	if (((maxVersion())[1] / 1000) >= 13) do windows.processPostedMessages() 
)

fn formatString s v: #() tag: "$"= (
	for i in 1 to v.count  do (
		s = substituteString s (tag + i as string) (v[i] as string)
	)
	
	return s
)

fn getFileMb f = (
	if (not doesFileExist f) do return 0.0
	s = (getFileSize f) / 1048576.0
	return ((s * 100) as integer) / 100.0
)

fn trimString s tag: "" = (
	s = s as string
	return (trimLeft (trimRight s tag) tag)
)

fn isCanOpenMaxFile f = (
	local fv = try ((getMaxFileVersionData f)[1]) catch (undefined)
	local mv = (maxVersion())[1]
	
	if (fv == undefined) do return false
	
	return fv <= mv
)

fn freezeUi = (
    source = ""
    source += "using System;\n"
    source += "using System.Runtime.InteropServices;\n"
    source += "class WindowsGhosting\n"
    source += "{\n"
    source += " [DllImport(\"user32.dll\")]\n"
    source += " public static extern void DisableProcessWindowsGhosting();\n"
    source += "}\n"
  
    csharpProvider = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
    compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"
  
    compilerParams.GenerateInMemory = on
    compilerResults = csharpProvider.CompileAssemblyFromSource compilerParams #(source)
  
    assembly = compilerResults.CompiledAssembly
    windowsGhosting = assembly.CreateInstance "WindowsGhosting"
    windowsGhosting.DisableProcessWindowsGhosting()
)

try(closeRolloutFloater _fGCBatchRepacker) catch()
global _fGCBatchRepacker = newRolloutFloater "" 300 640

rollout _rGCBatchRepacker_Main "Main" (
	local removePreviewsList = #("*.jpg", "*.jpeg", "*.png")
	local removeSysFilesList = #("desktop.ini", "Thumbs.db")
	local ptrnPackedByModelPacker = "GC-*"
	local ptrnPackedButNeedCheckVray = "*-2019-VRay"
	local ptrnPackedButNeedCheckCorona = "*-2019-Corona"
	global _DATA_ = #()
		
	group "Input Path With Archives" (
		edittext edtInputPath "" readonly: true across: 2 align: #left fieldwidth: 215 height: 22		
        button btnSearchInputPath "..." width: 35 height: 24  align: #right offset: [0, -1]
	)
	
	group "Output Path" (
		edittext edtOutPath "" readonly: true across: 2 align: #left fieldwidth: 215 height: 22		
        button btnSearchOutPath "..." width: 35 height: 24  align: #right offset: [0, -1]
	)
		
	group "Archives" (
		label lblTotalCaptin "Total " align: #left across: 2
		label lblTotalCnt ": (0)" align: #left across: 2 offset: [-104, 0]		
		label lblSelectedFor "Selected for Repack" align: #left across: 2
		label lblSelectedForCnt ": (0)" align: #left across: 2 offset: [-32, 0]
		
		multiListBox lbxList "" items: #() height: 20
		
		label lblDummy1 "" height: 3
		button btnSelectAll "Select All" width: 100 across: 2
		button btnDeselectAll "Deselect All" width: 100
		
		checkbox cbxCheckOnlyMissingTextures "Check only Missing textures for 'GC-*.max' files" checked: true
		
		progressBar pbProgress "" height: 6 color: orange value: 0 offset: [0, 5]
		label lblStatus "" align: #left offset: [0, 5]
		button btnStartBatchProcess "Repack" width: 260 height: 32 enabled: false
	)
	
	fn toggleUI s = (
		lbxList.enabled = s
		btnSelectAll.enabled = s
		btnDeselectAll.enabled = s
		btnStartBatchProcess.enabled = s
		btnSearchInputPath.enabled = s
		btnSearchOutPath.enabled = s
	)
	
	fn updateUI = (
		local ss = lbxList.selection as array
		local i = ss.count
		btnStartBatchProcess.enabled = i > 0
		lblSelectedForCnt.caption = ": (" + (i as string) + ")"
		btnStartBatchProcess.caption = "Repack (" + (i as string) + ")"
	)
	
	fn getFilesRecursive root ptrn: "*.max" = (
        local dd = getDirectories (root + "/*")
        local ff = getFiles (root + "/" + ptrn)
        for i in dd do join ff (getFilesRecursive i ptrn: ptrn)
        
        return ff
    )
	
	fn getRender = (
        local r = renderers.current as string
        
        if matchpattern r pattern:"*Corona*" do return "Corona"
        if matchpattern r pattern:"*V_Ray*" do return "Vray"
        if matchpattern r pattern:"*Default_Scanline*" do return "Scanline"
        if matchpattern r pattern:"*mental_ray*" do return "Mentalray"
        if matchpattern r pattern:"*iray_Renderer*" do return "IRay"
        if matchpattern r pattern:"*maxwell*" do return "Maxwell"
        if matchpattern r pattern:"*Arnold*" do return "Arnold"
            
        return "UnsupportedRender"
    )
	
	fn getPackVersion = (
        v = maxVersion()
        v = 2000 + ((v[1] / 1000) - 2)
        
        return (v - 3) as string
    )
	
	fn recursiveShowMaps om t = (
		local c = getNumSubMtls om
		if (c >= 1) then (
			for i in 1 to c do (
				sm = getSubMtl om i
				if sm != undefined do (
					recursiveShowMaps sm t
				)
			)
		) else(
			try(showTextureMap om t)catch()
		)
	)
	
	fn toggleVpMaps t scope: objects = (
		for o in scope do(
			if o.material != undefined do(
				recursiveShowMaps o.material t
			)
		)
	)
	
	fn loadSettings = (
		local p1 = '@'.g "INPUT_PATH"
		if (p1 != "" and doesDirectoryExist p1) do edtInputPath.text = p1
		
		local p2 = '@'.g "OUT_PATH"
		if (p2 != "" and doesDirectoryExist p2) do edtOutPath.text = p2
	)
	
	fn getData = (
		local p = edtInputPath.text
		if (p == "") do return #()
		
		local items = #()
		
		for i in getFiles (p + "*.zip") do (
			append items i			
		)
		
		::_DATA_ = items
		return items
	)
	
	fn updateList = (
		local items = getData()
		
		local l = for i in items collect getFileNameFile i
		
		lblTotalCnt.caption = formatString ": ($1)" v: #(items.count)
		
		lbxList.items = l
	)
	
	fn absolutePathInAtsOps = (
		a = #()
		
		ATSOps.Visible = false
		ATSOps.Visible = true		
		ATSOps.Refresh()
		ATSOps.GetFiles &a
		ATSOps.SelectFiles a
		ATSOps.ResolveSelectionToAbsolute()
		ATSOps.Refresh()
		ATSOps.Visible = false
		
		a = #()
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
		
		-- Remove curr path
		for i in d do (
			i.filename = substituteString i.filename o ""
		)
		
		setMAXFileAssetMetadata f d
		
		return out
	)
	
	fn setRenderByMaterials = (
		local l = #()
		 
		for o in objects where o.material != undefined do (
			local m = o.material
			
			if(classOf m == Multimaterial) then (
				for z in m.materialList where z != undefined do (
					appendIfUnique l z
				)
			) else (				
				appendIfUnique l m
			)
		)
		
		local a = #(
			#(#Scanline, 0),
			#(#Corona, 0),
			#(#Vray, 0),
			#(#Other, 0)		
		)
		
		for i in l do (
			local c = (classOf i) as string
			
			if (MatchPattern c pattern: "Corona*") do a[2][2] += 1
			if (MatchPattern c pattern: "Vray*") do a[3][2] += 1
			if (MatchPattern c pattern: "Standardmaterial*") do a[1][2] += 1
			if (MatchPattern c pattern: "PhysicalMaterial*") do a[1][2] += 1
		)
		
		fn sortFn v1 v2 = (
			local d = v1[2] - v2[2]
			
			if (d < 0.0) do return 1
			if (d > 0.0) do return -1
			return 0
		)
		
		qsort a sortFn
		
		local r = a[1][1]
		
		case r of (		
			#Corona: renderers.current = CoronaRenderer()
			#Vray: renderers.current = VRay()
			default: renderers.current = DefaultScanlineRenderer()
		)
		
		l = #()
		a = #()
		r = undefined
	)
	
	fn filterFiles ff = (
		struct filterStruct (files, type)
		
		-- If found GC- in name = skip all max files
		/*for f in ff do (
			local n = getFilenameFile f
			if (MatchPattern n pattern: ptrnPackedByModelPacker and findString n "Scanline" == undefined) do return (filterStruct files: #() type: #skipAll)
		)*/
			
		local filt = #()
		for f in ff do (
			local n = getFilenameFile f
			
			if (cbxCheckOnlyMissingTextures.checked) then (
				-- Skip archives without GC- prefix for MissingTextures Check				
				if (MatchPattern n pattern: ptrnPackedByModelPacker) do append filt f
			) else (	
				-- If packed by old Model Packer without GC- but with postfix -2019-Corona/2019-Vray = check only this files				
				if (MatchPattern n pattern: ptrnPackedButNeedCheckVray) do append filt f
				if (MatchPattern n pattern: ptrnPackedButNeedCheckCorona) do append filt f
			)
		)
		
		-- If not filtered return all list
		if (cbxCheckOnlyMissingTextures.checked) then (
			if (filt.count != 0) do return (filterStruct files: filt type: #checkTexturesOnly)
		) else (
			if (filt.count != 0) do return (filterStruct files: filt type: #repackAndDelete)
		)
		
		return (filterStruct files: #() type: #skipAll)
		
		--return (filterStruct files: ff type: #repackAll)
	)
	
	fn renameToOriginalScene o = (
		local maxFiles = getFilesRecursive o ptrn: "*.max"
		
		for f in maxFiles do (
			local n = getFilenameFile f
			if (
				not MatchPattern n pattern: ptrnPackedByModelPacker and
				not MatchPattern n pattern: "Original-Scene-*"
			) do (
				local p = getFilenamePath f
				local nn = p + "Original-Scene-" + n + ".max"
				renameFile f nn
			)
		)		
	)
	
	fn runBatchRepack = (
		local statusMsg = "Progress: $1/$2 ($3%) | $4 left | Selected $2 from $5"
		local robocopy = @"C:\Windows\System32\Robocopy.exe"
			
		local p1 = edtInputPath.text
		local p2 = edtOutPath.text
		local z = zipSimpleWrapper()
		local v = getPackVersion()
		local iterator = 0
		
		
		if (p1 == "" or not doesDirectoryExist p1) do return messageBox "Please select Input Path" title: "Error!"
		if (p2 == "" or not doesDirectoryExist p2) do return messageBox "Please select Output Path" title: "Error!"
		
		local data = getData()
		
		with redraw off (
			local ss = lbxList.selection as array
			
			for id in ss do (
				iterator += 1
				local i = data[id]
				local n = getFilenameFile i
				
				local o = p2 + n + @"\"
				local isTexExists = true
				o = substituteString o "/" @"\"
					
				-- Remove dir with archive name if exist
				local cmd = "rmdir /s /q \"" + o + "\""
				hiddenDosCommand cmd exitCode: &exitcode donotwait: false
				
				-- Extract
				z.extract i o
				
				-- Normalize archive (move all files from subdir to root)
				local ff = getFiles (o + "*.*")
				local dd = getDirectories (o + "*")
				if (ff.count == 0 and dd.count == 1) do (					
					local d1 = substituteString dd[1] "/" @"\"
					local d2 = substituteString o "/" @"\"
					
					local cmd = "" + robocopy + " /s /move \"" + (trimRight d1 @"\") + "\" \"" + (trimRight d2 @"\") + "\""				
					hiddenDosCommand cmd exitCode: &exitcode donotwait: false
					
					cmd = "rmdir /s /q \"" + d1 + "\""
					hiddenDosCommand cmd exitCode: &exitcode donotwait: false
					
					print ("Archive " + n + " normalized!")
				)
				
				-- Remove previews			
				for b in removePreviewsList do (
					for i in (getFiles (o + b)) do deleteFile i
				)
				
				-- Remove system files
				for b in removeSysFilesList do (
					local ff = getFilesRecursive o ptrn: b
					for i in ff do deleteFile i
				)
				
				-- Filter max files
				local maxFiles = getFilesRecursive o ptrn: "*.max"
				local filt = filterFiles maxFiles
				local filteredMaxFiles = filt.files
				local filteredMaxType = filt.type
				
				-- If check only textures, just check and pack as is
				if (filteredMaxType == #checkTexturesOnly) do (
					for f in filteredMaxFiles do (
						emptyTexList = isAllTexturesPresent f o						
						if (emptyTexList.count != 0) do (
							isTexExists = false
							
							print "                                                  "
							print "++++++++++++++++++++++++++++++++++++++++++++++++++"
							print ("Check scene: " + f)
							print "Missing textures: "
							for l in emptyTexList do print ("\t " + l)
						)
					)
					
					local pref = ""
					if (not isTexExists) do (
						pref = "Missing-Textures-"						
					) 
					
					local an = p2 + pref + n + ".zip"
					z.archivate an o
					
					continue
				)
				
				-- Resave all max files
				for f in filteredMaxFiles do (
					resetMaxFile #noPrompt
					try(setVRaySilentMode()) catch()
					loadMaxFile f useFileUnits: true quiet:true
					
					-- Save render
					currentRender = renderers.current
					
					-- Save units
					tmpSystemType = units.SystemType
					tmpSystemScale = units.SystemScale 
					tmpSystemScale = units.DisplayType
					
					-- Save gamma
					tmpClrCorrectionMode = IDisplayGamma.colorCorrectionMode
					tmpIdGamma = IDisplayGamma.gamma 
					
					local tmp = o + "__tmp.max"
					saveNodes objects tmp quiet:true
					
					resetMaxFile #noPrompt
					
					try (
						units.SystemType = tmpSystemType
						units.SystemScale = tmpSystemScale
						units.DisplayType= tmpSystemScale
					) catch ()
						
					IDisplayGamma.colorCorrectionMode = tmpClrCorrectionMode 
					IDisplayGamma.gamma = tmpIdGamma
					
					--try(renderers.current = currentRender)catch()
					
					try(setVRaySilentMode()) catch()
					
					mergeMAXFile tmp #select #mergedups #renameMtlDups #noRedraw quiet:true
					deleteFile tmp
						
					select objects
					
					-->>>>> Actions
						
					-- Disabled default render usage
					-- Set render by counting materials in scene
					setRenderByMaterials()		
					
					toggleVpMaps true
					
					deleteKeys objects #allKeys
					
					max tool zoomextents all
					max views redraw
					
					local r = getRender()
					local nn = formatString "GC-repack-$1-$2-$3.max" v: #(n, v, r)
					
					absolutePathInAtsOps()
					
					-- Save				
					saveMaxFile (o + nn) saveAsVersion: (v as integer) quiet:true
					resetMaxFile #noPrompt
					
					if (filteredMaxType == #repackAndDelete) do deleteFile f
					
					-- Check if all textues exist
					emptyTexList = isAllTexturesPresent (o + nn) o
					if (emptyTexList.count != 0) do isTexExists = false
				)
				
				-- Add Original-Scene to files without GC-
				renameToOriginalScene o
				
				-- Add prefix Missing-Textures- if some textures are missing
				local pref = ""
				if (not isTexExists) do pref = "Missing-Textures-"
				
				local an = p2 + pref + n + ".zip"
				
				z.archivate an o
				
				pbProgress.value = (100.0 * iterator / ss.count)
				lblStatus.caption = formatString statusMsg v: #(iterator, ss.count, pbProgress.value, ss.count - iterator, data.count)
				
				boost()
			)	
		)
		
		ff1 = (getFiles (p1 + "*.zip")).count as string
		ff2 = (getFiles (p2 + "*.zip")).count as string
		
		m = "Repacking completed!\n\n"
		m += "Input folder archives: " + ff1 + "\n"
		m += "Output folder archives: " + ff2
			
		messageBox m title: "Success!"		
		ShellLaunch p2 ""
	)
	
	on btnSearchInputPath pressed do (
		local d = '@'.g "INPUT_PATH"
		local p = getSavePath initialDir: d
		
		if (p == undefined) do return false
		p += @"\"
		
		edtInputPath.text = p
		'@'.s "INPUT_PATH" p
		
		updateList()
	)
		
	on btnSearchOutPath pressed do (
		local d = '@'.g "OUT_PATH"
		local p = getSavePath initialDir: d
		
		if (p == undefined) do return false
		p += @"\"
		
		edtOutPath.text = p
		'@'.s "OUT_PATH" p
		
		updateList()
	)
	
	on _rGCBatchRepacker_Main open do (
		freezeUi()
		
		loadSettings()
		updateList()
	)
	
	on btnDeselectAll pressed do (
		lbxList.selection = #{}
		updateUI()
	)
	
	on btnSelectAll pressed do (		
		lbxList.selection = for i in 1 to lbxList.items.count collect i
		updateUI()
	)
	
	on lbxList selectionEnd do (
		updateUI()
	)
	
	on btnStartBatchProcess pressed do (
		runBatchRepack()
	)
	
	on lbxList doubleClicked v do (
		local v = try(v as integer) catch(0)
		if(v == 0) do return false
		print ::_DATA_
		local i = ::_DATA_[v]
		if(i == undefined) do return false
		
		local msg = "\nDo you want to open destination folder?"			
		
		if(not doesFileExist i) do return messageBox "Folder not exist!" title: "Warning!"
		ShellLaunch (getFilenamePath i) ""
	)
)

rollout _rGCBatchRepacker_About "About" (
	group "Description" (
		dotNetControl edtDescription "System.Windows.Forms.Textbox" align:#center height: 60
	)
	
	label lblDummy1 ""
    
	label lblName "" 
	label lblVer ""
	label lblClient ""
	
	label lblDummy2 ""
	
	label lblAuthor ""
	hyperlink lblCopy ""  align: #center
	
	label lblDummy3 ""
	
	timer tmrRestart "" active: false interval: 300
	    
	fn downloadFile url dl = (
		deleteFile dl
		w = dotNetObject "System.Net.WebClient"			
		try(
			spm = dotNetClass "System.Net.ServicePointManager"
			spm.SecurityProtocol = spm.SecurityProtocol.TLS12				
			w.DownloadFile (url + "?time=" + timestamp() as string) dl				
		) catch(
			return false
		)
		
		return true
	)
	
	fn bgUpdate = (
		local url = "https://raw.githubusercontent.com/MastaArt/GC-Batch-Repack/main/"
		local main = url + "GC-Batch-Repack.ms"
		
		local additionalFiles = #("7za.exe", "archivate.bat", "extract.bat", "Install GC-Batch-Repack.mcr")
		
		local this = getThisScriptFileName()
		local p = getFileNamePath (getThisScriptFileName())
		local dl = this + ".tmp"
		local r = downloadFile main dl
		if(not r or not doesFileExist dl) do return print "Can't download updates!"
		local vn = getIniSetting dl "INFO" "VERSION"
		local vo = getIniSetting this "INFO" "VERSION"
		
		if(vn > vo) do (
			deleteFile this
			renameFile dl this
			
			for n in additionalFiles do (
				downloadFile (url + n) (p + n)
			)
			
			tmrRestart.active = true
		)
		
		deleteFile dl
	)
	
	fn updateWorker = (
		m = dotnetobject "CSharpUtilities.SynchronizingBackgroundWorker"
		m.WorkerSupportsCancellation = true 
		m.CancelAsync() 
		dotNet.addEventHandler m "DoWork" bgUpdate
		m.RunWorkerAsync()	
	)
	
    fn getScriptInfo s releaseInfo: "" =  (
        if(releaseInfo != "") do (
            local r = getINISetting s releaseInfo
            return r
        )
		
        local v = getINISetting s "INFO" "VERSION"
        local a = getINISetting s "INFO" "AUTHOR"
        local n = getINISetting s "INFO" "NAME"
        local o = ""
		for i in (getINISetting s "ABOUT") do o += i + "\r\n"
        local d = getINISetting s "INFO" "DEV"
        local h = getINISetting s "INFO" "HELP"
        local c = getINISetting s "INFO" "CLIENT"
        
		struct data (version, author, name, description, developer, client, help, releases)
		
        local r = for i in (getINISetting s) where (i != "ABOUT" and i != "SCRIPT" and i != "COPY") collect i
		
		return (data version: v author: a name: n description: o developer: d client: c help: h releases: r)
    )
	
	on tmrRestart tick do (
		this = getThisScriptFileName()
		try(fileIn this) catch()
		vo = getIniSetting this "INFO" "VERSION"
		m = ("Script updated to version " + vo + "!\n\n\n")
		for c in (getIniSetting this vo) do (
			m += c + "\n"
		)
		
		messageBox m title: "Success!" beep: false
		tmrRestart.active = false
	)

    on _rGCBatchRepacker_About open do (
		edtDescription.MultiLine = true
		edtDescription.WordWrap = true
		edtDescription.ReadOnly = true
		edtDescription.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").FixedSingle
		
		
        local i = getScriptInfo (getThisScriptFilename())
		
        lblName.caption = i.name
        lblAuthor.caption = i.author
        lblVer.caption = i.version
        lblCopy.address = lblCopy.caption = i.developer
        lblClient.caption = i.client
		edtDescription.text = i.description
		
		try (_fGCBatchRepacker.title = i.client) catch()
		try (_rGCBatchRepacker_Main.title = i.name + " v" +  i.version) catch()
		
		updateWorker()
    )		
)

addRollout _rGCBatchRepacker_Main _fGCBatchRepacker rolledUp: false
addRollout _rGCBatchRepacker_About _fGCBatchRepacker rolledUp: true