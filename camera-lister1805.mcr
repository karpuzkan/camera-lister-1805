macroScript Camera_Lister category:"Cameras" tooltip:"Camera Lister"
Icon:#("Cameras", 1)
AutoUndoEnabled:true
(
-- Globals
-- RollOut Floater
global CameraListenerRollout

-- Camera Selection Box
global CheckButton = #()

-- Scene States
global SceneStates = #()
	
-- Getting Cams
global CamCollection = for cams in cameras where superClassOf cams ==camera collect cams
if CamCollection == undefined then CamCollection = #()

for cam in cameras do (	
		setUserProp cam "RenderCheck" ((if (getUserProp cam "RenderCheck" != undefined) then (getUserProp cam "RenderCheck") else "true") as string)
		setUserProp cam "SceneState" ((if (getUserProp cam "SceneState") != undefined then (getUserProp cam "SceneState") else if (SceneStates.count > 1) then  "0") as string)
		setUserProp cam "RenderWidth" ((if (getUserProp cam "RenderWidth" != undefined) then (getUserProp cam "RenderWidth") else "1920") as integer)
		setUserProp cam "RenderHeight" ((if (getUserProp cam "RenderHeight" != undefined) then (getUserProp cam "RenderHeight") else "1080") as integer)
		--setUserProp cam "GlobalCheck" ((if (getUserProp cam "GlobalCheck" != undefined) then (getUserProp cam "GlobalCheck") else "true") as string)
	)
global ReadyToRender = for cams in CamCollection where getUserProp cams "RenderCheck" collect cams
global Info = (ReadyToRender.count as string)+" in "+(CamCollection.count as string) + " camera ready"

-- sort function
fn compareNames str1 str2 = stricmp str1.name str2.name
-- run sort function
if CamCollection != undefined then qSort CamCollection compareNames
	
-- Global Variables
global DefaultRenderPath = if(getAppData TrackViewNodes 001 == undefined) then "" else getAppData TrackViewNodes 001
setAppData TrackViewNodes 001 (DefaultRenderPath as string)

--global DefaultGlobalExposure = if(getAppData TrackViewNodes 002 == undefined) then 10.0 else getAppData TrackViewNodes 002
--setAppData TrackViewNodes 002 (DefaultGlobalExposure as string)

--global DefaultGlobalWhiteB = if(getAppData TrackViewNodes 003 == undefined) then "(color 255 255 255)" else getAppData TrackViewNodes 003
--setAppData TrackViewNodes 003 (DefaultGlobalWhiteB as string)

global DefaultResMul = if(getAppData TrackViewNodes 004 == undefined) then 1.0 else getAppData TrackViewNodes 004
setAppData TrackViewNodes 004 (DefaultResMul as string)

global DefaultFileFormat = if(getAppData TrackViewNodes 005 == undefined) then ".jpg" else getAppData TrackViewNodes 005
setAppData TrackViewNodes 005 (DefaultFileFormat  as string)

global DefaultCxr = if(getAppData TrackViewNodes 006 == undefined) then true else getAppData TrackViewNodes 006
setAppData TrackViewNodes 006 (DefaultCxr as string)

-- Session Variables
global RenderRatio = 1
global NetRenderActive = 1

-- Scene States
global ssm = sceneStateMgr
for i in 1 to ssm.getCount() do 
(
	SceneStates[i] = ssm.GetSceneState i
)

global CamSub

-- Functions
-- global declarations
global BtnCheck
global ChangeName
global SetCurrentView
global UserProps
global CameraProps
global RenderScene
global SendBatch
-- Camera Functions
	-- select btn
function BtnCheck index current = (
	select CamCollection[index as integer]
	for i in CamSub.controls where ((ClassOf i) as string) == "CheckButtonControl" and (i as string) != "CheckButtonControl:"+current do i.checked=false	
	)
	-- change cam name
function ChangeName index newvalue = (
	CamCollection[index].name=newvalue
	textindex = ((index-1)*15+3)
	CamSub.controls[textindex].tooltip = newvalue
	)
	-- change user props
function UserProps index propname newvalue = (
	SetUserProp CamCollection[index as integer] propname newvalue
	SetCurrentView index
	)

	-- change camera props
function CameraProps index propname newvalue = (
	index = index as integer
	setProperty (CamCollection[index]) (propname as string) newvalue
	
	if propname == "auto_vertical_tilt_correction" and newvalue == false then CamCollection[index].vertical_tilt_correction=0; CamCollection[index].horizontal_tilt_correction=0
	
	if propname == "white_balance_custom" then CamCollection[index].white_balance_type = 2
	)	
	
	-- set current view
fn SetCurrentView index = (
	index = index as integer
	viewport.setCamera CamCollection[index]
	
	if SceneStates.count > 1 then (
		sceneName = ssm.GetSceneState ((getUserProp (CamCollection[index]) "SceneState") as integer)
		if sceneName != undefined then ssm.RestoreAllParts (sceneName)
	)

	renderWidth= (getUserProp (CamCollection[index]) "RenderWidth") as integer
	renderHeight= (getUserProp (CamCollection[index]) "RenderHeight") as integer
	displaySafeFrames = true
	)
	
	-- render cameras
fn RenderScene = (
	-- path error
	if DefaultRenderPath =="" then return messagebox "Please Fill Render Path"
	
		for rendering in 1 to CamCollection.count do (
			 if (keyboard.escPressed) do (
				 exit
				 print "camera lister canceled!"
				
			 )
			-- close scene dialog
			renderSceneDialog.close()
			index = rendering as integer
			-- set current view
			cam = CamCollection[index]
			SetCurrentView index
			
			-- variables for local props to change later if global activated
			--oldExposure = cam.exposure_value
			--oldWhiteType = cam.white_balance_type
			--oldWhiteColor = cam.white_balance_custom	
			
			-- get render props
			renderPath = (GetAppData trackViewNodes 001) as string
			renderWidth= (getUserProp cam "RenderWidth") as integer * (GetAppData trackViewNodes 004 as float)
			renderHeight= (getUserProp cam "RenderHeight") as integer * (GetAppData trackViewNodes 004 as float)
			
			-- check global active
			--if ((getUserProp cam "GlobalCheck")==true) then (
			--	cam.white_balance_type = 2
			--	setProperty (cam) "exposure_value" ((getAppData trackViewNodes 002) as float)
			--	setProperty (cam) "white_balance_custom" (execute(getAppData trackViewNodes 003))
			--)
			
			-- render
			if((getUserProp cam "RenderCheck") == true) then (
				max quick render
				CoronaRenderer.CoronaFp.saveAllElements ((renderPath+"\\"+(cam.name as string)+(GetAppData trackViewNodes 005 as string)) as string)
				if (DefaultCxr as booleanClass) then CoronaRenderer.CoronaFp.dumpVfb ((renderPath+"\\"+(cam.name as string)+".cxr") as string)
				--deleteFile ((renderPath+"\\"+(cam.name as string)+".Alpha"+saveFormat) as string)
			)
			-- set back old values
			--cam.exposure_value = oldExposure
			--cam.white_balance_type = oldWhiteType
			--cam.white_balance_custom = oldWHiteColor
			)
	)	
	
	-- send to batch
fn  SendBatch = (
	cleanviews = batchRenderMgr.numViews
	for i = cleanviews to 1 by -1 do
			batchRenderMgr.deleteView i
	
	if DefaultRenderPath =="" then return messagebox "Please Fill Render Path"
		
	for rendering in 1 to CamCollection.count do (
		index = rendering as integer
		cam = CamCollection[index]
		
		-- get render props
		renderPath = (GetAppData trackViewNodes 001) as string
		renderWidth= (getUserProp cam "RenderWidth") as integer * (renderRatio as float)
		renderHeight= (getUserProp cam "RenderHeight") as integer * (renderRatio as float)
		sceneName = ssm.GetSceneState ((getUserProp (CamCollection[index]) "SceneState") as integer)
		
		-- create views
		currentview = batchRenderMgr.CreateView cam
		currentview.overridePreset = true
		currentview.name = cam.name
		currentview.width = renderWidth * (renderRatio as float)
		currentview.height = renderHeight * (renderRatio as float)
		currentview.sceneStateName = sceneName
		currentview.outputFilename = ((renderPath+"\\"+(cam.name as string)+saveFormat) as string)
		)
		batchRenderMgr.netRender = NetRenderActive
		batchRenderMgr.Render()
	)	

-- Global Edit Rollout
rollout cameraListener "Global Preferences" (
	button renderS "Render" align:#left pos:[620,10,0] width:70
	button renderB "Batch" align:#left pos:[690,10,0] width:70
	checkbutton check_net "Net?" align:#left pos:[760, 10,0] toolTip:"Make Double Width and Height"
	editText renderP "Render Path" align:#left pos:[10,10,0] width:500 text:(DefaultRenderPath as string)
	editText renderF align:#left pos:[510,10,0] width:100 text:(DefaultFileFormat as string)
	--dropdownlist bFormats "" align:#left items:#(".jpg",".exr", ".tiff") pos:[520,10,0] width:100
	--spinner GlobalExposure width:50 range:[-4,15,(DefaultGlobalExposure as float)] type:#integer pos:[10,50,0] toolTip:"Global Exposure Control"
	--colorpicker GlobalWhiteB color:(execute DefaultGlobalWhiteB) pos:[70,50,0] toolTip:"Global White Balance Custom Color"
	spinner ResMul "ResolutionX " alig:#left pos:[60,60,0] width:60 range:[-4,15,(DefaultResMul as float)] toolTip:"Resolution Multiplication By N Number"
	button objlayer "LFO" align:#left pos:[160,60,0] toolTip:"Create Layers from selected Objects"
	button statelayer "SSL" align:#left pos:[200,60,0] toolTip:"Create Scene States from layers"
	button camlayer "CL" align:#left pos:[240,60,0] toolTip:"Create Free Camera from Layers"
	button massassign "MA" align:#left pos:[280,60,0] toolTip:"Mass Assign"
	checkbutton Cxr "CXR" align:#left pos:[350,60,0] toolTip:"Save also cxr (for corona only)" checked:(DefaultCxr as booleanClass)
	button prevCam "Prev" align:#left pos:[0,90,0] toolTip:"Prev Camera" width:80 height:30
	button nextCam "Next" align:#left pos:[80,90,0] toolTip:"Next Camera" width:80 height:30
	label camlabel Info align:#center pos:[520, 50,0] style_sunkenedge:true width:270 height:50

	
	on renderS pressed do (
		RenderScene()
	)
		
	on renderB pressed do (
		SendBatch()
	)
		
	on check_net changed state do (
		NetRenderActive = state
	)
	
	on prevCam pressed do (
		active = getActiveCamera()
		item = findItem CamCollection active as integer
		count = CamCollection.count
		if (item-1) == 0 then index=count else index=(item-1)
		
		SetCurrentView index
	)
	
	on nextCam pressed do (
		active = getActiveCamera()
		item = findItem CamCollection active as integer
		count = CamCollection.count
		if (item+1) > count then index=1 else index=(item+1)
		
		SetCurrentView index
	)
	
	on massassign pressed do (
		rollout mass_dialog "Mass Assign"
		(
			spinner RenderW "Render Width" range:[320,8000,320] type:#integer
			spinner RenderH "Render Height" range:[320,8000,320] type:#integer
			spinner Focal "Focal Length" range:[16,120,80] type:#integer
			checkbutton RenderCam "Render Cam" checked:true
			button okey "Save"
			
			on okey pressed do
			(
				removeRollout camSub CameraListenerRollout
				for cam in CamCollection do
				(
					setUserProp cam "RenderWidth" RenderW.value as string
					setUserProp cam "RenderHeight" RenderH.value as string
					setUserProp cam "RenderCheck" RenderCam.state as string
					cam.focal_length_mm = Focal.value
				)
			)
		)
		
		createDialog mass_dialog style:#(#style_titlebar, #style_border, #style_sysmenu, #style_minimizebox)
	)
	
	on objlayer pressed do (
		if selection.count > 0 then
		(
			selectedObj = Selection as array
			for i in selectedObj do (
				if(isGroupMember i) then (
					parent = i.parent
					parent.pivot = [parent.center.x,parent.center.y,parent.min.z]
					parent.pos = [0,0,0]

					if(LayerManager.getLayerFromName parent.name == undefined) then (
						layer = LayerManager.newLayer()
						layer.setname parent.name
						layer.addnode i
						layer.addnode parent
						layer.ishidden = true			
					) else (
						layer = LayerManager.getLayerFromName parent.name
						layer.addnode i
					)
					
				) else (
					i.pivot = [i.center.x,i.center.y,i.min.z]
					i.pos = [0,0,0]
					
					layer = LayerManager.newLayer()
					layer.setname i.name
					layer.addnode i
					layer.ishidden = true
				)
			)
		)
	)
	
	on statelayer pressed do (
		global ssm = sceneStateMgr

		rollout parent_dialog "State From Layer"
		(
			edittext excludename ""
			label excludelabel "Hariç Layer Ismi"
			button okey "Save"
				
				on okey pressed do
				(
					for i = 0 to layerManager.count-1 do
					(
						
						excludelayer = LayerManager.getLayerFromName excludename.text
						ilayer = layerManager.getLayer i
						
						if ilayer.name != excludelayer.name do
						(
							if ilayer.name != "0" do
							(
								for j = 0 to layerManager.count-1 do
								(
									jlayer = layerManager.getLayer j
									
									if jlayer.name != excludename.text do jlayer.ishidden=true
								)
								ilayer.ishidden = false
								excludelayer.ishidden = false
								ssm.Capture ilayer.name #{6}
							)
						)
						
					)
				)
			)

			createDialog parent_dialog style:#(#style_titlebar, #style_border, #style_sysmenu, #style_minimizebox)
				
	)
	
	on camlayer pressed do (
		rollout cam_dialog "Camera Position"
		(
			pickbutton tempcam "Pick Camera" autodisplay:true 
			
			on tempcam picked obj do (
				
				for i = 0 to layerManager.count-1 do
				(
					ilayer = layerManager.getLayer i
					layerName = ilayer.name
					if ilayer.name != "0" do
					(
						
						cam = copy obj
						--cam.transform = obj.transform
						state = sceneStateMgr.FindSceneState layerName
						setUserProp cam "SceneState" state as string
						cam.name = layerName+"-01"
					)
				)
				destroyDialog cam_dialog
			)
		)
		createDialog cam_dialog
	)
		
	on renderP changed state do (
		DefaultRenderPath = state as string
		setAppData TrackViewNodes 001 DefaultRenderPath
		)

	on GlobalExposure changed state do (
		setAppData TrackViewNodes 002 (state as string)
		)
		
	on GlobalWhiteB changed state do (
		setAppData TrackViewNodes 003 (state as string)
		)
		
	on ResMul changed state do (
		setAppData TrackViewNodes 004 (state as string)
	)
		
	on renderF changed state do (
		DefaultFileFormat = state as string
		setAppData TrackViewNodes 005 DefaultFileFormat
		)
	
	on Cxr changed state do (
		DefaultCxr = state as booleanClass
		setAppData TrackViewNodes 006 (DefaultCxr as string)
		)
	)	
	
-- Scene Camera List
CamSub ="rollout CamSub \"Camera Lister\" "
CamSub+="(\n"

i = 1

for cam in CamCollection do
	(
		cname = i as string
		append CheckButton ("btn_"+cname)
		
		--ui element names
		checkRender = "render_"+cname
		checkbtn = "btn_"+cname
		nametext = "name_"+cname
		setview="setview_"+cname
		renderw="renderw_"+cname
		renderh="renderh_"+cname
		SSdropdown="SSdropdown_"+cname
		focal="focal_"+cname
		exposure="exposure_"+cname
		tilt = "tilt_"+cname
		clip = "clip_"+cname
		clipN = "clipN_"+cname
		clipF = "clipF_"+cname
		whiteB = "whiteB_"+cname
		globalCheck = "globalCheck_"+cname
		
		--defaults
		dname = cam.name as string
		dcheckbox = if selection.count > 0 and ((selection[1].name as string) == dname) and ((selection[2]) == undefined) then true else false
		
		--dcheckbox = true
		drender = (getUserProp cam "RenderCheck") as string
		dss =(if (getUserProp cam "SceneState") !="undefined" then (getUserProp cam "SceneState") else "0") as string
		drenderw = (getUserProp cam "RenderWidth") as string
		drenderh = (getUserProp cam "RenderHeight") as string
		dfocal = cam.focal_length_mm as string
		dexposure = cam.exposure_value as string
		dtilt = cam.auto_vertical_tilt_correction as string
		dclipN = cam.clip_near as string
		dclipF = cam.clip_far as string
		dwhiteB = cam.white_balance_custom as string
		dGlobalCheck = (getUserProp cam "GlobalCheck") as string
		print dcheckbox
		
		-- UI ELEMENTS
		
		CamSub+= "checkbutton "+checkbtn+" \"\" align:#left pos:[10,"+(i * 25) as string+"] width:10 height:20 toolTip:\"Select Camera\" checked:"+(dcheckbox as string)+"\n"
		CamSub+="button "+setview+" \"\" align:#left pos:[20,"+(i * 25) as string+"] width:10 height:20 toolTip:\"Set View\"\n"
		CamSub+="editText "+nametext+"  \"\" pos:[30,"+(i*25) as string+"] width:100 height:20 text:\""+dname+"\" toolTip:\""+dname+"\" \n"
		CamSub+="spinner "+RenderW+" \"\" width:50 range:[320,8000,"+drenderw+"] type:#integer pos:[140,"+(i * 25) as string+"] toolTip:\"Render Width\" \n"
		CamSub+="spinner "+RenderH+" \"\" width:50 range:[320,8000,"+drenderh+"] type:#integer pos:[190,"+(i * 25) as string+"] toolTip:\"Render Height\"\n"
		CamSub+="dropdownlist "+SSdropdown+" \"\" items:SceneStates pos:[250,"+(i*25) as string+"] selection:"+dss+" width:150 across:2 toolTip:\"Scene States\" \n"
		CamSub+="spinner "+focal+" \"\" width:50 range:[18,120,"+dfocal+"] pos:[405,"+(i * 25) as string+"] toolTip:\"Focal Length\"\n"
		CamSub+="spinner "+exposure+" \"\" width:50 range:[-5,15,"+dexposure+"] pos:[460,"+(i * 25) as string+"] type:#integer toolTip:\"Exposure Control\"\n"
		CamSub+="checkbox "+tilt+" \"\" across:2 pos:[515,"+(i * 25) as string+"] checked:"+dtilt+" toolTip:\"Vertical Tilt\" \n"
		CamSub+="checkbox "+clip+" \"\" across:2 pos:[540,"+(i * 25) as string+"] checked:"+(cam.clip_on as string)+" toolTip:\"Clip On\" \n"
		CamSub+="spinner "+clipN+" \"\" width:70 range:[0,1000000,"+dclipN+"] pos:[565,"+(i * 25) as string+"] type:#worldunits toolTip:\"Clip Near\"\n"
		CamSub+="spinner "+clipF+" \"\" width:70 range:[0,1000000,"+dclipF+"] pos:[640,"+(i * 25) as string+"] type:#worldunits toolTip:\"Clip Far\"\n"
		CamSub+="colorpicker "+whiteB+" \"\" color:"+dwhiteB+" pos:[710,"+(i * 25) as string+"] toolTip:\"White Balance Custom Color\"\n"
		--CamSub+="checkbox "+globalCheck+" \"\" across:2 pos:[760,"+(i * 25) as string+"] checked:"+dGlobalCheck+" toolTip:\"Global Assign\" \n"
		CamSub+="checkbox "+checkRender+" \"\" across:2 pos:[790,"+(i * 25) as string+"] checked:"+dRender+" toolTip:\"Render This Cam\" \n"
		
		-- HANDLERS
		-- clip on handler begin
		CamSub+="\non "+checkRender+" changed state do (\n"
		CamSub+="UserProps \""+(i as string)+"\" \"RenderCheck\" state \n"
		CamSub+=")\n"
		-- clip on handler end
		
		-- btn handler begin
		CamSub+="\non "+checkbtn+" changed state do (\n"
		CamSub+="BtnCheck \""+(i as string)+"\" \""+checkbtn+"\" \n"
		--CamSub+="UncheckAll "+checkbtn+" \n"
		CamSub+=")\n"
		-- btn handler end
			
		-- setview handler begin
		CamSub+="\non "+setview+" pressed do (\n"
		CamSub+="SetCurrentView \""+cname+"\" \n"
		CamSub+=")\n"
		-- btn handler end
	
		-- name handler begin
		CamSub+="\non "+nametext+" changed state do (\n"
		CamSub+="ChangeName "+cname+" state \n"
		CamSub+=")\n"
		-- btn handler end
		
		-- renderw handler begin
		CamSub+="\non "+renderw+" changed state do (\n"
		CamSub+="UserProps \""+(i as string)+"\" \"RenderWidth\" state \n"
		CamSub+=")\n"
		-- renderw handler end
		
		-- renderh handler begin
		CamSub+="\non "+renderh+" changed state do (\n"
		CamSub+="UserProps \""+(i as string)+"\" \"RenderHeight\" state \n"
		CamSub+=")\n"
		-- renderh handler end
		
		-- scene state rollout begin
		CamSub+="\non "+SSdropdown+" selected state do (\n"
		CamSub+="UserProps \""+(i as string)+"\" \"SceneState\" state \n"
		CamSub+=")\n"
		-- scene state rollout end
				
		-- focal handler begin
		CamSub+="\non "+focal+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"focal_length_mm\" state \n"
		CamSub+=")\n"
		-- focal handler end
		
		-- exposure handler begin
		CamSub+="\non "+exposure+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"exposure_value\" state \n"
		CamSub+=")\n"
		-- exposure handler end
		
		-- exposure handler begin
		CamSub+="\non "+tilt+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"auto_vertical_tilt_correction\" state \n"
		CamSub+=")\n"
		-- exposure handler end
		
		-- clip on handler begin
		CamSub+="\non "+clip+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"clip_on\" state \n"
		CamSub+=")\n"
		-- clip on handler end
		
		-- clip on handler begin
		CamSub+="\non "+clipN+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"clip_near\" state \n"
		CamSub+=")\n"
		-- clip on handler end
		
		-- clip on handler begin
		CamSub+="\non "+clipF+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"clip_far\" state \n"
		CamSub+=")\n"
		-- clip on handler end
		
		-- clip on handler begin
		CamSub+="\non "+whiteB+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"white_balance_custom\" state \n"
		CamSub+=")\n"
		-- clip on handler end
		
		-- clip on handler begin
		CamSub+="\non "+globalCheck+" changed state do (\n"
		CamSub+="UserProps \""+(i as string)+"\" \"GlobalCheck\" state \n"
		CamSub+=")\n"
		-- clip on handler end
		
		CamSub+=" \n"
		i+=1
		)
		
CamSub+="\n)"
		
try (closeRollOutFloater CameraListenerRollout) catch()
CameraListenerRollout = newRolloutFloater "Camera Lister" 820 600
		
addRollOut cameraListener CameraListenerRollout
addRollOut (execute CamSub) CameraListenerRollout
)