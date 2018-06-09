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
		setUserProp cam "GlobalCheck" ((if (getUserProp cam "GlobalCheck" != undefined) then (getUserProp cam "GlobalCheck") else "true") as string)
		setUserProp cam "SceneState" ((if (getUserProp cam "SceneState") != undefined then (getUserProp cam "SceneState") else if (SceneStates.count > 1) then  "0") as string)
		setUserProp cam "RenderWidth" ((if (getUserProp cam "RenderWidth" != undefined) then (getUserProp cam "RenderWidth") else "1920") as integer)
		setUserProp cam "RenderHeight" ((if (getUserProp cam "RenderHeight" != undefined) then (getUserProp cam "RenderHeight") else "1080") as integer)
)

-- sort function
fn compareNames str1 str2 = stricmp str1.name str2.name
-- run sort function
if CamCollection != undefined then qSort CamCollection compareNames
	
-- Global Variables
global DefaultRenderPath = if(getAppData TrackViewNodes 001 == undefined) then "" else getAppData TrackViewNodes 001
setAppData TrackViewNodes 001 (DefaultRenderPath as string)

global DefaultResMul = if(getAppData TrackViewNodes 004 == undefined) then 1.0 else getAppData TrackViewNodes 004
setAppData TrackViewNodes 004 (DefaultResMul as string)

global DefaultFileFormat = if(getAppData TrackViewNodes 005 == undefined) then ".jpg" else getAppData TrackViewNodes 005
setAppData TrackViewNodes 005 (DefaultFileFormat  as string)

global DefaultCxr = if(getAppData TrackViewNodes 006 == undefined) then false else getAppData TrackViewNodes 006
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

-- Rollouts
global GlobalPreferencesRO
global GlobalChangeRO
global CamerasRO

-- Functions
-- global declarations
global BtnCheck
global ChangeName
global SetCurrentView
global UserProps
global CameraProps
global RenderScene
global SendBatch
global ReadyInfo
-- Camera Functions

	-- Ready Render Info Bar
fn ReadyInfo = (
	ReadyToRender = for cams in CamCollection where getUserProp cams "RenderCheck" collect cams
	return (ReadyToRender.count as string)+" in "+(CamCollection.count as string) + " camera ready"
	)
	
global Info = 	ReadyInfo()
	-- select btn
function BtnCheck index current = (
	select CamCollection[index as integer]
	unselectbuttons = for i in CamerasRO.controls where ((ClassOf i) as string) == "CheckButtonControl" and (i as string) != "CheckButtonControl:"+current collect i
	if unselectbuttons !=undefined then for i in unselectbuttons do i.checked=false
	)
	-- change cam name
function ChangeName index newvalue = (
	CamCollection[index].name=newvalue
	textindex = ((index-1)*15+3)
	)
	-- change user props
function UserProps index propname newvalue = (
	SetUserProp CamCollection[index as integer] propname newvalue
	SetCurrentView index
	)

	-- change camera props
function CameraProps index propname newvalue setview:true = (
	index = index as integer
	cam = CamCollection[index]
	setProperty cam (propname as string) newvalue
	if propname == "focal_length_mm" then cam.specify_fov=off
	if propname == "auto_vertical_tilt_correction" and newvalue == false then cam.vertical_tilt_correction=0; cam.horizontal_tilt_correction=0
	if setview==true then SetCurrentView index
	)	
	
	-- set current view
fn SetCurrentView index = (
	
	index = index as integer
	viewport.setCamera CamCollection[index]
	--print index
	
	if SceneStates.count > 1 then (
		if (getUserProp (CamCollection[index]) "SceneState") == "undefined" then return messagebox "first select a scene state"
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
	--if DefaultRenderPath =="" then return messagebox "Please Fill Render Path"
		
	willrender = for cams in CamCollection where getUserProp cams "RenderCheck" collect cams
	totalcam=willrender.count
	renderedcam=0
	leftcam=0
	
	GlobalPreferencesRO.RenderingInfo.visible=true
	GlobalPreferencesRO.RenderingInfo.text="rendering started"
	
	start_total=timestamp()
	
		for rendering in willrender do (
			 if (keyboard.escPressed) do (
				 messagebox "canceled!"
				 exit
			 )
			-- close scene dialog
			renderSceneDialog.close()
			--index = rendering as integer
			 cam = rendering
			 index = findItem CamCollection rendering
			-- render
			SetCurrentView index
			
			-- get render props
			renderPath = (GetAppData trackViewNodes 001) as string
			renderWidth= (getUserProp cam "RenderWidth") as integer * (GetAppData trackViewNodes 004 as float)
			renderHeight= (getUserProp cam "RenderHeight") as integer * (GetAppData trackViewNodes 004 as float)
			 
			max quick render
			CoronaRenderer.CoronaFp.saveAllElements ((renderPath+"\\"+(cam.name as string)+(GetAppData trackViewNodes 005 as string)) as string)
			if (DefaultCxr as booleanClass) then CoronaRenderer.CoronaFp.dumpVfb ((renderPath+"\\"+(cam.name as string)+".cxr") as string)
			 
			renderedcam+=1
			leftcam=(totalcam-renderedcam)
			GlobalPreferencesRO.RenderingInfo.visible=true
			GlobalPreferencesRO.RenderingInfo.text=(renderedcam as string)+" camera rendered, "+(leftcam as string)+" camera left"

			estimated = (((timestamp()-start_total)/1000)/renderedcam)*leftcam
			willtake = ((dotnetclass "TimeSpan").FromSeconds estimated).ToString()
			GlobalPreferencesRO.EstimatedInfo.visible=true
			GlobalPreferencesRO.EstimatedInfo.text="estimated remaining "+willtake
		)
	GlobalPreferencesRO.EstimatedInfo.visible=false
	took = ((dotnetclass "TimeSpan").FromSeconds ((timestamp()-start_total)/1000)).ToString()
	GlobalPreferencesRO.RenderingInfo.text="finished in "+took
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
rollout GlobalPreferencesRO "Global Preferences" (
	editText renderP "Render Path" align:#left pos:[10,10,0] width:500 height:20 text:(DefaultRenderPath as string)
	editText renderF align:#left pos:[510,10,0] width:100  height:20 text:(DefaultFileFormat as string)
	checkbutton Cxr "CXR" align:#left pos:[620,10,0] toolTip:"Save also cxr (for corona only)" checked:(DefaultCxr as booleanClass)
	button renderS "Render" align:#left pos:[700,10,0] width:70
	button renderB "Batch" align:#left pos:[770,10,0] width:70
	checkbutton check_net "Net?" align:#left pos:[840, 10,0] toolTip:"Make Double Width and Height"
	
	spinner ResMul "ResolutionX " alig:#left pos:[60,60,0] width:60 range:[1,10,(DefaultResMul as float)] toolTip:"Resolution Multiplication By N Number"
	button objlayer "LFO" align:#left pos:[160,60,0] toolTip:"Create Layers from selected Objects"
	button statelayer "SSL" align:#left pos:[200,60,0] toolTip:"Create Scene States from layers"
	button camlayer "CL" align:#left pos:[240,60,0] toolTip:"Create Free Camera from Layers"
	button addCoronaMod "ACC" align:#left pos:[280,60,0] toolTip:"Add Corona Camera Modifier"
	
	button prevCam "Prev" align:#left pos:[0,90,0] toolTip:"Prev Camera" width:80 height:30
	button nextCam "Next" align:#left pos:[80,90,0] toolTip:"Next Camera" width:80 height:30
	button slightShow "Auto" align:#left pos:[160,90,0] tooltip:"Slight Show Cameras" width:80 height:30
	spinner slightTick "" align:#left pos:[250,95,0] tooltip:"Set Interval for Slight Show in seconds" width:40 height:30 type:#integer range:[1,120,1]
	label slightTickLabel "second" align:#left pos:[300,95,0]
	label ReadyRender Info pos:[520, 50,0] width:270 height:20
	label RenderingInfo "rendering..." pos:[520, 70,0] width:270 height:20 visible:false
	label EstimatedInfo "Estimated Info" pos:[520, 90,0] width:270 height:20 visible:false
	
	timer clock "testClock" active:false
	
	on slightShow pressed do (
		clock.interval = (slightTick.value*1000)
		clock.active = true
	)
	
		on clock tick do (
			SetCurrentView (clock.ticks)
			if clock.ticks == CamCollection.count do clock.active = false
	)
	
	on addCoronaMod pressed do (
		coronamod = CoronaCameraMod()
		for i in CamCollection do (
			
			for currentmod in i.modifiers do (
				deletemodifier i currentmod
				)
			addmodifier i coronamod
		)
	)
	
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
			editText camline "Camera End"
			
			on tempcam picked obj do (
				
				for i = 0 to layerManager.count-1 do
				(
					ilayer = layerManager.getLayer i
					layerName = ilayer.name
					if ilayer.name != "0" do
					(
						maxops.cloneNodes #(obj) newNodes:&cam
						state = sceneStateMgr.FindSceneState layerName
						setUserProp cam "SceneState" state as string
						cam.name = layerName+"-"+(camline.text)
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

fn changeGlobal controller controllername type state = (
	if controller =="GlobalCheck" then (
		for cam in CamCollection do (
			i = (findItem camCollection cam)
			setUserProp cam controller state
			execute("CamerasRo."+controllername+"_"+(i as string)+"."+type+"="+(state as string))
		)
	) else (
		for cam in CamCollection do (
			if (getUserProp cam "GlobalCheck") ==true then (
				i = (findItem camCollection cam)
				
				if getUserProp cam controller !=undefined then (
						setUserProp cam controller state
						execute("CamerasRo."+controllername+"_"+(i as string)+"."+type+"="+(state as string))
				) else (
					execute("CamerasRo."+controllername+"_"+(i as string)+"."+type+"="+(state as string))
					CameraProps i controller state setview:false
				)
			)
		)
	)
)
-- Global Change Rollout
rollout GlobalChangeRO "Global Change" (
		checkbox GlobalCheck across:2 pos:[10,0,0] checked:false toolTip:"Check for Global Change"
		spinner RenderW width:50  pos:[270,0,0] range:[320,8000,1920] type:#integer toolTip:"Render Width"
		spinner RenderH width:50 pos:[330,0,0] range:[320,8000,1080] type:#integer toolTip:"Render Height"
		dropdownlist SSdropdown items:SceneStates pos:[390,0,0] width:180 across:2 selection:0 toolTip:"Scene States"
		checkbox focus across:2 pos:[580,0,0] checked:false toolTip:"Depth Of Field"
		checkbox tilt across:2 pos:[605,0,0] checked:false toolTip:"Vertical Tilt"
		spinner focal width:50 range:[18,120,80] pos:[630,0,0] toolTip:"Focal Length"
		checkbox clip across:2 pos:[690,0,0] checked:false toolTip:"Clip On"
		spinner clipN width:70 range:[0,1000000,1000] pos:[715,0,0] type:#worldunits toolTip:"Clip Near"
		spinner clipF width:70 range:[0,1000000,10000] pos:[790,0,0] type:#worldunits toolTip:"Clip Far"
		checkbox checkRender across:2 pos:[870,0,0] checked:false toolTip:"Render This Cam"
	
		on GlobalCheck changed state do (
			changeGlobal "GlobalCheck" "GlobalCheck" "checked" state
		)
		on RenderW changed state do (
			changeGlobal "RenderWidth" "renderw" "value" state
		)
		on RenderH changed state do (
			changeGlobal "RenderHeight" "renderh" "value" state
		)
		on SSdropdown selected state do (
			changeGlobal "SceneState" "SSdropdown" "selection" state
		)
		on focus changed state do (
			changeGlobal "use_dof" "focus" "checked" state
		)
		on tilt changed state do (
			changeGlobal "auto_vertical_tilt_correction" "tilt" "checked" state
		)
		on focal changed state do (
			changeGlobal "focal_length_mm" "focal" "value" state
		)
		on clip changed state do (
			changeGlobal "clip_on" "clip" "checked" state
		)
		on clipN changed state do (
			changeGlobal "clip_near" "clipN" "value" state
		)
		on clipF changed state do (
			changeGlobal "clip_far" "clipF" "value" state
		)
		on checkRender changed state do (
			changeGlobal "RenderCheck" "render" "checked" state
			GlobalPreferencesRO.ReadyRender.text=ReadyInfo()
		)
	)
-- GLobal Change Rollout	
-- Scene Camera List
CamSub ="rollout CamerasRO \"Camera Lister\" "
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
		focus="focus_"+cname
		tilt = "tilt_"+cname
		clip = "clip_"+cname
		clipN = "clipN_"+cname
		clipF = "clipF_"+cname
		GlobalCheck = "globalCheck_"+cname
		
		--defaults
		dname = cam.name as string
		dcheckbox = if selection.count > 0 and ((selection[1].name as string) == dname) and ((selection[2]) == undefined) then true else false
		drender = (getUserProp cam "RenderCheck") as string
		dss =(if (getUserProp cam "SceneState") !="undefined" then (getUserProp cam "SceneState") else "0") as string
		drenderw = (getUserProp cam "RenderWidth") as string
		drenderh = (getUserProp cam "RenderHeight") as string
		dfocus=cam.use_dof as string
		dfocal = cam.focal_length_mm as string
		dtilt = cam.auto_vertical_tilt_correction as string
		dclipN = cam.clip_near as string
		dclipF = cam.clip_far as string
		dGlobalCheck = (getUserProp cam "GlobalCheck") as string
		
		-- UI ELEMENTS
		
		CamSub+="checkbox "+GlobalCheck+" \"\" across:2 pos:[10,"+(i * 25) as string+"] checked:"+dGlobalCheck+" toolTip:\"Check for Global Change\" \n"
		CamSub+= "checkbutton "+checkbtn+" \"\" align:#left pos:[35,"+(i * 25) as string+"] width:20 height:20 toolTip:\"Select Camera\" checked:"+(dcheckbox as string)+"\n"
		CamSub+="button "+setview+" \"\" align:#left pos:[55,"+(i * 25) as string+"] width:20 height:20 toolTip:\"Set View\"\n"
		CamSub+="editText "+nametext+"  \"\" pos:[75,"+(i*25) as string+"] width:180 height:20 text:\""+dname+"\" toolTip:\""+dname+"\" \n"
		CamSub+="spinner "+RenderW+" \"\" width:50  pos:[270,"+(i * 25) as string+"] range:[320,8000,"+drenderw+"] type:#integer toolTip:\"Render Width\" \n"
		CamSub+="spinner "+RenderH+" \"\" width:50 pos:[330,"+(i * 25) as string+"] range:[320,8000,"+drenderh+"] type:#integer toolTip:\"Render Height\"\n"
		CamSub+="dropdownlist "+SSdropdown+" \"\" items:SceneStates pos:[390,"+(i*25) as string+"] selection:"+dss+" width:180 across:2 toolTip:\"Scene States\" \n"
		CamSub+="checkbox "+focus+" \"\" across:2 pos:[580,"+(i * 25) as string+"] checked:"+dfocus+" toolTip:\"Depth Of Field\" \n"
		CamSub+="checkbox "+tilt+" \"\" across:2 pos:[605,"+(i * 25) as string+"] checked:"+dtilt+" toolTip:\"Vertical Tilt\" \n"
		CamSub+="spinner "+focal+" \"\" width:50 range:[18,120,"+dfocal+"] pos:[630,"+(i * 25) as string+"] toolTip:\"Focal Length\"\n"
		CamSub+="checkbox "+clip+" \"\" across:2 pos:[690,"+(i * 25) as string+"] checked:"+(cam.clip_on as string)+" toolTip:\"Clip On\" \n"
		CamSub+="spinner "+clipN+" \"\" width:70 range:[0,1000000,"+dclipN+"] pos:[715,"+(i * 25) as string+"] type:#worldunits toolTip:\"Clip Near\"\n"
		CamSub+="spinner "+clipF+" \"\" width:70 range:[0,1000000,"+dclipF+"] pos:[790,"+(i * 25) as string+"] type:#worldunits toolTip:\"Clip Far\"\n"
		CamSub+="checkbox "+checkRender+" \"\" across:2 pos:[870,"+(i * 25) as string+"] checked:"+dRender+" toolTip:\"Render This Cam\" \n"
		
		-- HANDLERS
		CamSub+="\non "+checkRender+" changed state do (\n"
		CamSub+="UserProps \""+(i as string)+"\" \"RenderCheck\" state \n"
		CamSub+="GlobalPreferencesRO.ReadyRender.text=ReadyInfo() \n"
		CamSub+=")\n"
		
		CamSub+="\non "+checkbtn+" changed state do (\n"
		CamSub+="BtnCheck \""+(i as string)+"\" \""+checkbtn+"\" \n"
		CamSub+=")\n"
		
		CamSub+="\non "+setview+" pressed do (\n"
		CamSub+="SetCurrentView \""+cname+"\" \n"
		CamSub+=")\n"

		CamSub+="\non "+nametext+" changed state do (\n"
		CamSub+="ChangeName "+cname+" state \n"
		CamSub+=")\n"

		CamSub+="\non "+renderw+" changed state do (\n"
		CamSub+="UserProps \""+(i as string)+"\" \"RenderWidth\" state \n"
		CamSub+="SetCurrentView \""+cname+"\" \n"
		CamSub+=")\n"

		CamSub+="\non "+renderh+" changed state do (\n"
		CamSub+="UserProps \""+(i as string)+"\" \"RenderHeight\" state \n"
		CamSub+="SetCurrentView \""+cname+"\" \n"
		CamSub+=")\n"

		CamSub+="\non "+SSdropdown+" selected state do (\n"
		CamSub+="UserProps \""+(i as string)+"\" \"SceneState\" state \n"
		CamSub+=")\n"

		CamSub+="\non "+focal+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"focal_length_mm\" state \n"
		CamSub+=")\n"

		CamSub+="\non "+focus+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"use_dof\" state \n"
		CamSub+=")\n"

		CamSub+="\non "+tilt+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"auto_vertical_tilt_correction\" state \n"
		CamSub+=")\n"

		CamSub+="\non "+clip+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"clip_on\" state \n"
		CamSub+=")\n"

		CamSub+="\non "+clipN+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"clip_near\" state \n"
		CamSub+=")\n"

		CamSub+="\non "+clipF+" changed state do (\n"
		CamSub+="CameraProps \""+(i as string)+"\" \"clip_far\" state \n"
		CamSub+=")\n"

		CamSub+="\non "+globalCheck+" changed state do (\n"
		CamSub+="UserProps \""+(i as string)+"\" \"GlobalCheck\" state \n"
		CamSub+=")\n"
		
		CamSub+=" \n"
		i+=1
		)
		
	CamSub+="\n)"
		
try (closeRollOutFloater CameraListenerRollout) catch()
CameraListenerRollout = newRolloutFloater "Camera Lister" 900 600
addRollOut GlobalPreferencesRO CameraListenerRollout
addRollOut GlobalChangeRO CameraListenerRollout
addRollOut (execute CamSub) CameraListenerRollout
)