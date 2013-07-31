function SMART_TEST(simFlag)
%% PURPOSE: LOADS DATA EITHER FROM TDT BUFFER OR HTK FILES ON DISK, 
%% AUTOMATICALLY DETECTS EVENTS FROM ANALOG CHANNEL BASED ON THRESHOLD
%% AVERAGES AND PLOTS DATA AROUND EVENT
%% INPUT: simFlag= 1: load HTK Files
%%                 2: Data from TDT
%% TO ACCESS DATA STORED IN GUI, TYPE >> HANDLES=GUIDATE(GUIFIGUREHANDLE)
%% HANDLES.DATA --> HOLDS DATA VALUES
%% HANDLES.GUI --> HOLDS GUI COMPONENT HANDLES

%ADD FUNCTIONS IN FOLDER TO MATLAB PATH
[folderPath,b]=fileparts(which(mfilename));
addpath(genpath(folderPath));

% INITIATE FIGURE AND HANDLES
set(0,'DefaultFigureColor','w');
set(0, 'DefaultUipanelbackgroundColor','w');
set(0, 'DefaultUIControlBackgroundColor','w');
   fig = figure( 'Name', 'SMART', ...'
        'NumberTitle', 'off', ...
        'Toolbar', 'none', ...
        'MenuBar', 'none', ...        
        'Units','Normalized',...
        'Position',[0 0.2 .9 .7]);
    set(fig,'DefaultAxesgridlinestyle','-');
handles.simFlag=simFlag;

% SET DEFAULT VALUES
handles.data=defaultData(handles.simFlag);

% CREATE GUI AND AXES
handles=createGUI(handles,fig);
guidata(gcf,handles);

end % Main function

function data=defaultData(varargin)
% SETS DEFAULT PARAMETERS

sampling_rate = 400;
number_of_channels = 16;
ANnumber_of_channels = 4;
number_of_sec2read = 1;
dANproj_name =  {'Amp.dmata'};
sANproj_name =  {'Amp.smata'};
integration_time = .1;
avgEvent_freqs2plot = 1:17;
singleEvent_freqs2plot = avgEvent_freqs2plot;
num_freq_bands = length(avgEvent_freqs2plot);
window_around_event = 50;
window_around_event_ms = 1500;
constant = [];posInNewData_AfterCAR=[];
ANconstant = []; ANposInNewData = [];


time2collectBaseline = 20;%str2num(get(handles.time2collectBaseline,'String'));
desired_freq_plot = max(avgEvent_freqs2plot) ; %str2num(get(handles.desired_freq_plot,'String'));
freq_band_singlestacked =  max(avgEvent_freqs2plot)-1; %str2num(get(handles.freq_band_singlestacked,'String'));
desired_ANchan = 1;%str2num(get(handles.desired_ANchan,'String'));
threshold = .5;%str2num(get(handles.threshold,'String'));
subj_id = 'TEST';%get(handles.subj_id,'String');
number_of_electrodes_total=256;%str2num(elec_tmp{get(handles.get_total_electrodes,'Value')});
number_of_analog=length(desired_ANchan);
CARoption='16 Ch CAR';

f=whos;
data.Params=[];
for i=1:length(f)
    data.Params.(f(i).name)=eval([f(i).name ';']);
end

end


%% CREATE GUI FUNCTIONS
function handles=createGUI(handles,fig)
clf(fig);

% Contents of each panel
panelOrder={'User Input','EventCounter','Continual Plot',...
    'Average Spectrograms','Stacked Plots','MRI 1','MRI 2','MRI 3','MRI 4'};

% Position panels
% UserData handle specifies whether panel is docked (1) or undocked (0)
set(0,'DefaultUipanelBorderType','None');
i=1;
tmp=uipanel('Units','Normalized','Position',[ 0 2/3 .2 1/3],'Parent',fig,'UserData',1);
panel{i}=tmp;
i=2;
tmp=uipanel('Units','Normalized','Position',[ 0 1/3 .2 1/3],'Parent',fig,'UserData',1);
panel{i}=tmp;
i=3;
tmp=uipanel('Units','Normalized','Position',[ 0 0 .2 1/3],'Parent',fig,'UserData',1);
panel{i}=tmp;
i=4;
tmp=uipanel('Units','Normalized','Position',[ .2 1/2 .4 1/2],'Parent',fig,'UserData',1);
panel{i}=tmp;
i=5;
tmp=uipanel('Units','Normalized','Position',[ .6 1/2 .4 1/2],'Parent',fig,'UserData',1);
panel{i}=tmp;
i=6;
tmp=uipanel('Units','Normalized','Position',[ .2 0 .2 .5],'Parent',fig,'UserData',1);
panel{i}=tmp;
i=7;
tmp=uipanel('Units','Normalized','Position',[ .4 0 .2 .5],'Parent',fig,'UserData',1);
panel{i}=tmp;
i=8;
tmp=uipanel('Units','Normalized','Position',[ .6 0 .2 .5],'Parent',fig,'UserData',1);
panel{i}=tmp;
i=9;
tmp=uipanel('Units','Normalized','Position',[ .8 0 .2 .5],'Parent',fig,'UserData',1);
panel{i}=tmp;

for i=1:9
    %Set Panel properties
    set(panel{i},'BorderType','beveledout','BorderWidth',2);
    set(panel{i},'Title',panelOrder{i});
    set(panel{i},'Units','Pixels');
    pos=get(panel{i},'Position');
    
    %Create dock button
    a=uicontrol('Style','PushButton','Parent',panel{i},'Callback',{@nDock,i},...
        'Position',[pos(3)-20 pos(4)-10 20 10],'String','D');
    set(a,'Units','Normalized');

    %Create disable button
    a=uicontrol('Style','PushButton','Parent',panel{i},'Callback',{@nDisable,i},...
        'Position',[pos(3)-40 pos(4)-10 20 10],'String','X');    
    set(a,'Units','Normalized');
    set(panel{i},'Units','Normalized');
end


% Set axes to panel and save handle
% handles.gui.PLOTNAME.handle is handle to axes
% handles.gui.PLOTNAME.plot is handle to plot
handles=createUserInput(panel{1},handles);
handles.gui.aveSpec.handle=axes('Parent',panel{4},'ActivePositionProperty','Position','Position',[0 0 1 1]);
handles.gui.stacked.handle=axes('Parent',panel{5},'ActivePositionProperty','Position','Position',[0 0 1 1]);
handles.gui.eventCounter.handle=axes('Parent',panel{2},'ActivePositionProperty','Position','Position',[0 0 1 1]);
handles.gui.continual.handle=axes('Parent',panel{3},'ActivePositionProperty','Position','Position',[0 0 1 1]);
for i=1:4
    handles.gui.mri(i).handle=axes('Parent',panel{i+5},'Position',[0 0 1 1],'Visible','off');
end
handles.gui.fig=fig;
    function nDisable( eventSource, eventData, whichpanel )
        %DISABLE PLOT BY SETTING VISIBILITY OF AXES AND ITS CHILDREN
        c=get(panel{whichpanel},'Children');
        if strcmp(get(c(1),'Visible'),'off')
            set(c(1),'Visible','on');
            set(get(c(1),'Children'),'Visible','on');
        else
            set(c(1),'Visible','off');
            set(get(c(1),'Children'),'Visible','off');
        end
    end

    function nDock( eventSource, eventData, whichpanel ) 
        %DOCK/UNDOCK FUNCTION
        %DOCKED POSITION STORED IN PANEL'S USERDATA
        if ~get(panel{whichpanel},'UserData')
            % Put it back into the layout
            newfig = get( panel{whichpanel}, 'Parent' );
            original=get(newfig,'UserData');
            set(panel{whichpanel},'Parent',original.Parent,'Position',original.Pos);         
            delete( newfig );
            set(panel{whichpanel},'UserData',1);
        else
            % Take it out of the layout and into new figure
            pos = getpixelposition( panel{whichpanel} );
            original.Pos=get(panel{whichpanel},'Position');
            panelParent=get(panel{whichpanel},'Parent');
                      newfig = figure( ...
                'Name', get( panel{whichpanel}, 'Title' ), ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'Toolbar', 'none', ...
                'CloseRequestFcn', {@nDock, whichpanel} );
            figpos = get( newfig, 'Position' );
            set( newfig, 'Position', [figpos(1,1:2), pos(1,3:4)] );
            set( panel{whichpanel}, 'Parent', newfig, ...
                'Units', 'Normalized', ...
                'Position', [0 0 1 1] );
            original.Parent=panelParent;
            set(newfig,'Userdata',original);
            set(panel{whichpanel},'UserData',0);
        end
    end

    function nCloseAll( ~, ~ )
        % User wished to close the application, so we need to tidy up        
        % Delete all windows, including undocked ones. We can do this by
        % getting the window for each panel in turn and deleting it.
        for ii=1:numel( panel )
            if isvalid( panel{ii} ) && ~strcmpi( panel{ii}.BeingDeleted, 'on' )
                figh = ancestor( panel{ii}, 'figure' );
                delete( figh );
            end
        end
    end % nCloseAll
end

function handles=createUserInput(panel,handles)
% MAKE USER INPUT INTERFACE AND BUTTONS
data=handles.data;
w=.4;%width
h=.1;%height
space=.005;%spacing

gui.userInput.panel=panel;

%Load Baseline
r=2;%Row number
gui.userInput.collectBaseline=uicontrol('Style','PushButton','String','Collect Baseline','Parent',gui.userInput.panel,...
    'Units','Normalized','Position',[.1 .9-(h+space)*r w h],'CallBack',@grabBaseline);

%Load MRI
r=r+1;
gui.userInput.loadMRI=uicontrol('Style','PushButton','String','Load MRI','Parent',gui.userInput.panel,...
    'Units','Normalized','Position',[.1 .9-(h+space)*r w h],'CallBack',@loadMRI);

%Start Data Collection
r=r+1;
gui.userInput.start=uicontrol('Style','PushButton','String','Start','Parent',gui.userInput.panel,...
    'Units','Normalized','Position',[.1 .9-(h+space)*r w h],'CallBack',@start);

%Stop
r=r+1;
gui.userInput.stop=uicontrol('Style','PushButton','String','Stop','Parent',gui.userInput.panel,...
    'Units','Normalized','Position',[.1 .9-(h+space)*r w h],'CallBack',@stop);

%More options
r=r+1;
gui.userInput.optionsButton=uicontrol('Style','PushButton','String','More Options','Parent',gui.userInput.panel,...
    'Units','Normalized','Position',[.1 .9-(h+space)*r w h],'CallBack',@optionsPopup);

%Help
r=r+1;
gui.userInput.optionsButton=uicontrol('Style','PushButton','String','Help','Parent',gui.userInput.panel,...
    'Units','Normalized','Position',[.1 .9-(h+space)*r w h],'CallBack',@displayGUIHelp);

handles.gui=gui;
end



function optionsPopup(varargin)
% MORE OPTIONS: grid size,plots, auto artifact rejection
handles=guidata(varargin{1});
w=.3;
h=.05;
space=.005;
popFig=figure('Color','w');

% Cell array with uicontrol parameters
% Column 1= field, 2= string, 3= type,4= popup choices
options={'desired_ANchan','Analog Ch','popup',{'1','2','3','4'};...
    'threshold','Analog Threshold','edit',{''};...
    'sampling_rate','Sampling Rate (Hz)','edit',{''}; ...
    'window_around_event_ms','Window Around Event (ms)','edit',{''};...
    'time2collectBaseline','Baseline Length (sec)','edit',{''};...
    'number_of_electrodes_total','Number electrodes','popup' {'256','64'};...
    'CARoption','Common Average Referece','popup',{'16 Ch CAR','Ave all Ch','None'}};
numericCharacters = '0123456789ij.-';

% Makes buttons and edit fields using cell array of uicontrol parameters
for r=1:size(options,1)
    %SET TEXT
    uicontrol('Style','Text','String',options{r,2},'Parent',popFig,...
        'Units','Normalized','Position',[.1 .9-(h+space)*r w h]);
    
    if strcmp(options{r,3},'popup') 
        %CREATE DROPDOWN MENU
        if isnumeric(handles.data.Params.(options{r,1}))
            value=find(strcmp(options{r,4},num2str(handles.data.Params.(options{r,1}))));
        else
            value=find(strcmp(options{r,4},(handles.data.Params.(options{r,1}))));
        end
        handles.gui.userInput.(options{r,1})=uicontrol('Style',options{r,3},'String',options{r,4},...
            'Parent',popFig,...
            'Units','Normalized','Position',[.5 .9-(h+space)*r w h],'Value',value);
    
    else
        %CREATE EDIT MENU
        handles.gui.userInput.(options{r,1})=uicontrol('Style',options{r,3},'String',num2str(handles.data.Params.(options{r,1})),...
            'Parent',popFig,...
            'Units','Normalized','Position',[.5 .9-(h+space)*r w h]);
    end
end

r=size(options,1)+1;

% Make apply changes button
uicontrol('Style','PushButton','String','Apply','Parent',popFig,...
        'Units','Normalized','Position',[.5 .9-(h+space)*r w h],'Callback',@applyChanges);
guidata(handles.gui.fig,handles);


    function applyChanges(varargin)
        % When clicked, extracts current value of uicontrols, and sets them
        % to corresponding parameters in handles.data.Params
        numericCharacters = '0123456789ij.-';
        for r=1:length(options)
            if strcmp(options{r,3},'popup')
                string=get(handles.gui.userInput.(options{r,1}),'String');
                choice=string{get(handles.gui.userInput.(options{r,1}),'Value')};
                if all(ismember(choice,numericCharacters))
                    handles.data.Params.(options{r,1})=str2num(choice);
                else
                    handles.data.Params.(options{r,1})=choice;
                end
            else
                handles.data.Params.(options{r,1})=str2num(get(handles.gui.userInput.(options{r,1}),'String'));
            end
        end
        guidata(handles.gui.fig,handles);
    end
end



%% START/STOP DATA ACQUISITION 
function start(varargin)
% START COLLECTING DATA

% GET PARAMETER VALUES
handles = guidata(varargin{1});
f=fieldnames(handles.data.Params);
for i=1:length(f)
    eval(sprintf('%s=deal(handles.data.Params.(f{i}));',f{i}));
end

f=fieldnames(handles.data.baselineStats);
for i=1:length(f)
    eval(sprintf('%s=deal(handles.data.baselineStats.(f{i}));',f{i}));
end


%SET TDT PROJECT NAME
if  number_of_electrodes_total == 64
    dproj_name = {'Amp.dmat1'};
    sproj_name = {'Amp.smat1'};
    to_plot_grid=8;
elseif number_of_electrodes_total == 256;
    dproj_name = {'Amp.dmat1';'Amp.dmat2';'Amp.dmat3';'Amp.dmat4'};
    sproj_name = {'Amp.smat1';'Amp.smat2';'Amp.smat3';'Amp.smat4'};
    to_plot_grid=16;
end

%% SET VARIABLES
window_around_event=round((window_around_event_ms/1000)*sampPerSecond);
handles.data.allStacked=zeros(number_of_electrodes_total,50,num_freq_bands,window_around_event+1);
handles.data.DataAfterCAR=zeros(number_of_electrodes_total, num_freq_bands, 4*60*sampling_rate);
handles.data.ANNewData_finalMAT=zeros(ANnumber_of_channels, 4*60*sampling_rate);
allStacked=handles.data.allStacked;
DataAfterCAR=handles.data.DataAfterCAR;
ANNewData_finalMAT=handles.data.ANNewData_finalMAT;
averages=repmat(handles.data.baselineStats.averages,[1 1 window_around_event+1]);
stdevs=repmat(handles.data.baselineStats.stdevs,[1 1 window_around_event+1]);
medians=repmat(handles.data.baselineStats.medians,[1 1 window_around_event+1]);


%% GET PLOTTING NUMBER PARAMETERS
handles=getElectrodeNums(handles,num_avgEvent_freqs2plot,...
    num_singleEvent_freqs2plot,...
    number_of_electrodes_total,...
    window_around_event,...
    to_plot_grid);
numberingParams=handles.data.numberingParams;

%% INITIATE PLOTS WITH ZEROS FOR DATA

% INITIATE AVE SPEC
to_plot=allStacked(:,1,:,:);
to_plot=squeeze(nanmean(to_plot,2));
to_plot = reshape_3Ddata(to_plot, window_around_event,size(to_plot,2), to_plot_grid);
handles.gui.aveSpec=plotAveSpec(handles.gui.aveSpec,'initiate',window_around_event,to_plot_grid,to_plot,number_of_electrodes_total,1,number_of_analog,num_avgEvent_freqs2plot,numberingParams);


% INITIATE STACKED
to_plot=mean(allStacked(:,1,desired_freq_plot,:),3);
to_plot = reshape_3Ddata(to_plot, window_around_event,1, to_plot_grid);
handles.gui.stacked=plotStacked(handles.gui.stacked,'initiate',window_around_event,to_plot_grid,to_plot,number_of_electrodes_total,1,numberingParams);

% INITIATE CONTINUAL
to_plot=squeeze(mean(allStacked(:,1,desired_freq_plot,1),3));
to_plot=real(reshape(to_plot,to_plot_grid,to_plot_grid))';
handles.gui.continual=plotContinual(handles.gui.continual,'initiate',to_plot);

% INITIATE EVENT COUNTER
handles.gui.eventCounter=plotEventCounter(handles.gui.eventCounter,'initiate');

% INITIATE MRI PLOTS IF MRI IMAGES ARE LOADED
for m=1:4
    if isfield('plot',handles.gui.mri(m))
        handles.gui.mri(m)=plotMRI(handles.gui.mri(m),'update',[],[],zeros(1,number_of_electrodes_total));
    end
end
%% 
bufferCounter = zeros(1,size(dproj_name,1));
ANbufferCounter = 0;
matlab_loopCounter = 0;
num_samples=0; %used to calculate faster average
last_used_ind=0;  %used to calculate faster average

if handles.simFlag==0
    DA = actxcontrol('TDevAcc.X');% Loads ActiveX methods
else
    DA=[];
end
handles.DA = DA;
guidata(handles.gui.fig,handles);

last_used_ind=-1;
good_event_count=0;
desired_ANchan = desired_ANchan(1);
try
    desired_ANchan2 = desired_ANchan(2);
catch
    desired_ANchan2=[];
end

%% INITIALIZE BOOKKEEPING VARIABLES
num_events = 1;
prev_num_events=0;
new_plot_flag=0;
finalPos=0;
finalPosA=0;
ecogFinalPos=0;
newEventFlag=0;
lastTime=0;
lastRawIdx=0;
nextRawIdx=1;
ecogAll.data=[];
ecogAll.sampFreq=sampling_rate;
simData=handles.simFlag;
averageSpec=[];

if simData==1 || DA.ConnectServer('Local')>0  %Checks to see if there is an OpenProject and Workbench load
    if simData==0
        DA.SetSysMode(3); pause(5); %Starts OpenEx project running and acquiring data. 1 = Standby, 2 = Preview, !!MUST CHANGE TO 3 WHEN RECORDING
    end
    if simData==1 || DA.GetSysMode>1 % Checks to see if the Project is running
        if simData==1 | not(isnan(DA.ReadTargetVEX(dproj_name{1},0,10,'F32','F64')))   %checks to see if it loaded the correct project
            try
                for i=1:length(dproj_name)
                    BufferSize(i)=DA.GetTargetSize(dproj_name{i});% returns the Buffer size (bookkeeping)
                end
                if event_flag ==1 || single_event_flag==1
                    ANBufferSize=DA.GetTargetSize(dANproj_name{1});% returns the Analog Buffer size (bookkeeping)
                    ANoldAcqPos=ANBufferSize;
                end
                oldAcqPos=BufferSize;
            end
            
            
            profile on
            while (simData==1 || DA.GetSysMode>1) 
                %% Retrieve data. Both loading from tdt and htk files ends 
                % with variables ecog.data and analog.data which holds the
                % current data chunk
                
                if simData==0;
                    % Get TDT data
                    % find place in TDT buffer, check for buffer wrap
                    % around, find place in MATLAB buffer
                    
%*******************NEED TO CHECK BLOCK START*********************************
                    [NewDataMAT,ANNewData,ANAcqPos,AcqPos,bufferCounter, ...
                        constant, ANconstant, posInNewData_AfterCAR, ANposInNewData,number_of_points2read,ANnumber_of_points2read]=...
                        getTDTData(DA,matlab_loopCounter,bufferCounter,ANbufferCounter,...
                        number_of_points2read, ANnumber_of_points2read,sproj_name,dproj_name,sANproj_name,dANproj_name,...
                        BufferSize,ANBufferSize, oldAcqPos, ANoldAcqPos,number_of_channels,ANnumber_of_channels, constant,ANconstant)
                    ecog.data=NewDataMAT;
                    ecog.sampFreq=sampling_frequency;
                    analog.data=ANNewData;
                    analog.sampFreq=sampling_frequency;
%*******************NEED TO CHECK BLOCK END*********************************

                else
                    if matlab_loopCounter==0
                        %On first loop, load all simulation data
                        if ~isfield(handles,'ecogAll')
                            % load simulation data from HTK files    
                            filepath=uigetdir;
                            [ecogAll,analogAll]=loadHTKData(filepath,number_of_electrodes_total,[]);
                            handles.ecogAll=ecogAll;
                            handles.analogAll=analogAll;
                            guidata(gcf,handles);
                        else
                            % use pre-loaded simulation files
                            ecogAll=handles.ecogAll;
                            analogAll=handles.analogAll;
                        end
                    end
                    % Grab new data segment 
                    [ecog,analog,lastTime]=grabDataBuffer(ecogAll,analogAll,lastTime);
                end
                
                %% APPLY COMMON AVERAGE REFERENCE 
                switch handles.data.Params.CARoption
                    case '16 Ch CAR'
                        ecog=subtractCAR_16ChanBlocks(ecog,badChannels,ecog);
                    case 'Ave Ch'
                        printf('option not available');
                        keyboard;
                    case 'None'
                        %No CAR
                end
                
                %% STORE RECENT DATA IN VARIABLE
                ecogAll.data(:,ecogFinalPos+1:ecogFinalPos+size(ecog.data,2))=ecog.data;
                ecogFinalPos=ecogFinalPos+size(ecog.data,2);
                
                %% CALCULATE STFT
                [ecogSTFT,nextRawIdx]=calcSTFT(ecogAll.data(:,nextRawIdx:ecogFinalPos),ecogAll.sampFreq,nextRawIdx);
                
                ANNewDataMAT=analog.data;                
                LogNewData=(ecogSTFT.data);
                
                %% UPDATE CONTINUAL PLOT
                if strcmp(get(handles.gui.continual.handle,'Visible'),'on');        
                    runningAverage = mean(squeeze(mean(LogNewData(:, desired_freq_plot,:),3)),2);
                    to_plot=real(reshape(runningAverage,to_plot_grid,to_plot_grid))';
                    handles.gui.continual=plotContinual(handles.gui.continual,'update',to_plot);
                end
                
                %% STORE IN DATA VARIABLE
                DataAfterCAR(:,:,finalPos+1:finalPos+size(LogNewData,3))=LogNewData;
                ANNewData_finalMAT(:,finalPosA+1:finalPosA+size(ANNewDataMAT,2))=ANNewDataMAT(:,1:size(ANNewDataMAT,2));
                
                %% KEEP TRACK OF TIME AFTER STFT
                if finalPos==0
                    specTimes(finalPos+1:finalPos+size(LogNewData,3))=ecogSTFT.time;
                else
                    specTimes(finalPos+1:finalPos+size(LogNewData,3))=ecogSTFT.time+specTimes(end);
                end
                finalPos=finalPos+size(LogNewData,3);
                finalPosA=finalPosA+size(ANNewDataMAT,2);
                
                %find events
                event=(ANNewData_finalMAT(desired_ANchan,:)>threshold);
                trigger=(diff(event)>0);
                detected_num_events = sum(trigger);
                
                if detected_num_events>0
                    %% GET EVENT TIMES
                    [num_events,~,eventTimes] = ...
                        parseEvents(ANNewData_finalMAT, finalPos, desired_ANchan,...
                        desired_ANchan2, threshold, threshold, analog.sampFreq, prev_num_events,...
                        [], [], number_of_analog,window_around_event/2);
                    
                    if num_events>prev_num_events
                        % num_events is #events after removing ones within 1 second, intialized to 0
                        prev_num_events = num_events;
                        newEventFlag=1;
                    else
                        newEventFlag=0;
                    end
                    
                    %% GRAB DATA AROUND EVENT
                    if  newEventFlag==1 && number_of_analog ==1
                        [averageSpec,num_samples,last_used_ind,allStacked,new_plot_flag,good_event_count] = average_event_window(num_events, eventTimes(1,:), window_around_event,...
                            DataAfterCAR,finalPos(1),number_of_electrodes_total,...
                            num_avgEvent_freqs2plot, avgEvent_freqs2plot,...
                            averageSpec, num_samples, last_used_ind,allStacked,good_event_count, ...
                            averages, stdevs,freq_band_singlestacked,specTimes);
                    elseif newEventFlag==1 && number_of_analog ==2
                        [averageSpec,last_used_ind,allStacked,new_plot_flag,current_num_events,lastSpec,lastSpec_event2,eventRelatedAvg2] =...
                            average_event_window_2_events(num_events, event_indices, window_around_event,window_after_event,...
                            DataAfterCAR,finalPos(1),number_electrodes ,num_freq_bands, freqs2plot,...
                            averageSpec, last_used_ind,allStacked,good_event_count, averages, stdevs,old_average_event2,freq_band_singlestacked)
                    end
                    
                    if  new_plot_flag==1 & newEventFlag==1
                        %% UPDATE EVENT COUNTER
                        if strcmp(get(handles.gui.eventCounter.handle,'Visible'),'on');
                            handles.gui.eventCounter=plotEventCounter(handles.gui.eventCounter,'newEvent',matlab_loopCounter,good_event_count)
                        end
                        
                        %% UPDATE AVERAGE SPECTROGRAM PLOTS
                        if strcmp(get(handles.gui.aveSpec.handle,'Visible'),'on');
                            to_plot=averageSpec;
                            to_plot = reshape_3Ddata(to_plot, window_around_event,size(to_plot,2), to_plot_grid);
                            handles.gui.aveSpec=plotAveSpec(handles.gui.aveSpec,'update',window_around_event,to_plot_grid,to_plot,number_of_electrodes_total,num_events,num_avgEvent_freqs2plot,numberingParams);
                            if number_of_analog==2
                                ZscoreEventRelatedAvg=(eventRelatedAvg2-averages)./stdevs;
                                flattened = reshape_3Ddata(to_plot, window_around_event,size(ZscoreEventRelatedAvg,2), to_plot_grid);
                                handles.gui.aveSpec=plotAveSpec(handles.gui.aveSpec,'update',window_around_event,to_plot_grid,to_plot,number_of_electrodes_total,num_events,2,numberingParams);
                            end
                        end
                        
                        %% UPDATE SINGLE STACKED PLOTS
                        if strcmp(get(handles.gui.stacked.handle,'Visible'),'on');
                            to_plot=mean(allStacked(:,1:good_event_count,desired_freq_plot,:),3);
                            to_plot = reshape_3Ddata(to_plot, window_around_event,good_event_count, to_plot_grid);
                            handles.gui.stacked=plotStacked(handles.gui.stacked,'update',window_around_event,to_plot_grid,to_plot,number_of_electrodes_total,good_event_count,numberingParams);
                        end
                        
                        %% UPDATE MRI PLOTS
                        to_plot=allStacked(:,1:good_event_count,:,:);
                        to_plot=squeeze(nanmean(to_plot,2));
                        sampInterval=round(size(to_plot,3)/2)-round(sampPerSecond/2):round(sampPerSecond/4):...
                            round(size(to_plot,3)/2)+round(sampPerSecond/2);
                        tp_toplot={sampInterval(1):sampInterval(2);sampInterval(2):sampInterval(3);...
                            sampInterval(3):sampInterval(4);sampInterval(4):sampInterval(5)};
                        for m=1:4
                            if strcmp(get(handles.gui.mri(m).handle,'Visible'),'on');  
                                mriplot = mean(mean(to_plot(:,desired_freq_plot,tp_toplot{m}),2),3);
                                handles.gui.mri(m)=plotMRI(handles.gui.mri(m),'update',[],[],mriplot);
                            end
                        end
                    end                    
                end
                
                
                try
                    ANoldAcqPos=ANAcqPos;
                end
                try
                    oldAcqPos=AcqPos;
                end
                
                
                % UPDATE CHANGES
                drawnow
                
                % IF LOOP IS LESS THAN .1 SEC, PAUSE
                if toc< .1
                    pause(.1)
                end
                
                % GET LOOP TIME FOR TESTING PURPOSES
                matlab_loopCounter=matlab_loopCounter+1;
                tmp (matlab_loopCounter)= toc;
               
            end
        else
            msgbox('Incorrect OpenEx Project')
        end
    else
        msgbox('OpenEx project Failed To Run')
    end
else
    msgbox('OpenEx project not loaded reload OpenEx project and restart MATLAB script')
end
DA.CloseConnection

end

function stop(varargin)
% STOP COLLECTING DATA
handles=guidata(varargin{1});
if handles.simFlag==1
    keyboard
else
    handles.DA.SetSysMode(1);
end
end


%% PLOTTING FUNCTIONS

function axisHandles=plotMRI(axisHandles,flag,img,xy,mr1data)

switch flag
    case 'initiate'
        axes(axisHandles.handle);cla;
        image(img);
        hold on
        axisHandles.plot= scatter(xy(1,:),xy(2,:),15,'filled');
    case 'update'       
        colormapjet = colormap('jet');       
        cmax = 3; cmin = -3;
        colormap_index = fix((mr1data-cmin)/(cmax-cmin)*length(colormapjet))+1;
        colormap_index(colormap_index>length(colormapjet)) = length(colormapjet);
        colormap_index(colormap_index<=0) = 1;
        set(axisHandles.plot,'CData',colormapjet(colormap_index,:)); 
end

end

function axisHandles=plotStacked(axisHandles,flag,window_around_event,to_plot_grid,to_plot,number_of_electrodes_total,num_events,numberingParams)
switch flag
    case 'initiate'
        %SINGLE STACKED PLOT
        axes(axisHandles.handle);
        cla;
        axisHandles.plot=pcolor(flipud(to_plot));
        shading interp;
        set(axisHandles.handle,'xtick',[0.5: (window_around_event+1):to_plot_grid*(window_around_event+1)]);
        set(axisHandles.handle,'Clim',[-7 7]);
        set(axisHandles.handle,'layer','top');
    case 'update'
        %children=get(axisHandle,'Children');
        %set(children(end),'CData',flipud(to_plot));
        cla(axisHandles.handle);
        axisHandles.plot=pcolor(axisHandles.handle,flipud(to_plot));
        set(axisHandles.handle,'Clim',[-7 7]);
        shading(axisHandles.handle,'interp');
        numberingParams.fig_num_y_stacked = [1:num_events:to_plot_grid*num_events];
        
        numberingParams.fig_num_y_stacked = reshape(repmat(numberingParams.fig_num_y_stacked, [to_plot_grid 1]),...
            number_of_electrodes_total, 1);
        numberingParams.stackedfig_dash_y = repmat([0 num_events*to_plot_grid],to_plot_grid,1)';
        line(numberingParams.fig_dash_x,numberingParams.stackedfig_dash_y,...
            'LineStyle','--','linewidth',1','color',[0 0 0],'Parent',axisHandles.handle);
        set(axisHandles.handle,'YTick',[0.5: num_events:to_plot_grid*num_events],...
            'xtick',[0.5: (window_around_event+1):to_plot_grid*(window_around_event+1)],...
            'XGrid','on','YGrid','on',...
            'XTickLabel',[],'YTickLabel',[]);
        set(axisHandles.handle,'gridLineStyle','-');
        text(numberingParams.fig_num_x, flipud(numberingParams.fig_num_y_stacked),...
            repmat(1,size(numberingParams.fig_num_y_stacked)), numberingParams.fig_nums,...
            'Parent',axisHandles.handle);
        set(axisHandles.handle,'layer','top');
        %drawnow
end
end

function axisHandles=plotContinual(axisHandles,flag,to_plot)
switch flag
    case 'initiate'
        axes(axisHandles.handle);cla;
        axisHandles.plot=imagesc(to_plot);
        title('Continual Plot')
        %set(axisHandle,'XTick',(1:size(to_plot,2))+.5,'YTick',(1:size(to_plot,1))+.5);
        set(axisHandles.handle,'XTickLabel',[]);
        set(axisHandles.handle,'YTickLabel',[]);
    case 'update'
        set(axisHandles.plot,'CData',to_plot);
        %drawnow;
end
end

function axisHandles=plotAveSpec(axisHandles,flag,window_around_event,to_plot_grid,to_plot,number_of_electrodes_total,num_events,number_of_analog,num_avgEvent_freqs2plot,numberingParams)
switch flag
    case 'initiate'
        for i=1:number_of_analog
            axes(axisHandles.handle);
            cla;      
            axisHandles.plot=pcolor(axisHandles.handle,flipud(to_plot));
            shading interp;
            set(axisHandles.handle,'CLim',[-3 3]);
            set(axisHandles.handle,'XTick',[0.5: (window_around_event+1):to_plot_grid*(window_around_event+1)]);
            set(axisHandles.handle,'YTick',[0.5: num_avgEvent_freqs2plot:to_plot_grid*num_avgEvent_freqs2plot]);
            set(axisHandles.handle,'YTickLabel','','XTickLabel','');
            set(axisHandles.handle,'gridLineStyle','-');
            text(numberingParams.fig_num_x, flipud(numberingParams.fig_num_y),...
                repmat(1,size(numberingParams.fig_num_x)),numberingParams.fig_nums);
            line(numberingParams.fig_dash_x,numberingParams.avgfig_dash_y,repmat(1,size(numberingParams.avgfig_dash_y)),'LineStyle','--','linewidth',1','color',[0 0 0]);
            set(axisHandles.handle,'layer','top');            
            grid on;         
        end
    case 'update'        
        set(axisHandles.plot,'Cdata',flipud(to_plot));
        %drawnow;
end
end

function axisHandles=plotEventCounter(axisHandles,flag,~,detected_num_events)
switch flag
    case 'initiate'
        axes(axisHandles.handle);cla;
        axisHandles.eventMat=zeros(8,8);
        axisHandles.plot=imagesc( axisHandles.eventMat);
        set(axisHandles.handle,'CLim',[-2 2])
        set(axisHandles.handle,'XTick',[0:size( axisHandles.eventMat,1)]+.5);
        set(axisHandles.handle,'YTick',[0:size( axisHandles.eventMat,2)]+.5);
        set(axisHandles.handle,'XTickLabel',[],'YTickLabel',[]);
        
        %plot(0,0,'*');
        grid on;
        x=meshgrid([1:size( axisHandles.eventMat,1)])';
        y=meshgrid([1:size( axisHandles.eventMat,2)]);
        t=cellfun(@num2str,num2cell(1:64),'UniformOutput',0);
        text(x(:),y(:),t);
        %hold on
    case 'update'
        %plot(axisHandles.handle,matlab_loopCounter,detected_num_events,'*');
    case 'newEvent'
        axisHandles.eventMat(1:detected_num_events)=2;
        set(axisHandles.plot,'CData', axisHandles.eventMat');
        %plot(axisHandles.handle,matlab_loopCounter,detected_num_events,'r*');
end
end

function handles=getElectrodeNums(handles,num_avgEvent_freqs2plot,num_singleEvent_freqs2plot,number_of_electrodes_total,window_around_event,to_plot_grid)
% coordinates for the electrode numbers
fig_num_y = [1.1:num_avgEvent_freqs2plot:to_plot_grid*num_avgEvent_freqs2plot];
fig_num_y = reshape(repmat(fig_num_y,[to_plot_grid 1]),number_of_electrodes_total,1);
fig_num_x = [.5:(window_around_event+1):to_plot_grid*(window_around_event+1)];
fig_num_x = reshape(repmat(fig_num_x,[1 to_plot_grid]),number_of_electrodes_total,1);
fig_nums = {};
for i = 1:number_of_electrodes_total
    fig_nums = [fig_nums {num2str(i)}];
end

% coordinates for the dash lines
avgfig_dash_y = repmat([0 num_avgEvent_freqs2plot*to_plot_grid],to_plot_grid,1)';
sigfig_dash_y = repmat([0 num_singleEvent_freqs2plot*to_plot_grid],to_plot_grid,1)';
fig_dash_x = repmat([round((window_around_event+1)/2):window_around_event+1:to_plot_grid*(window_around_event+1)],2,1);


f=whos;
f={f.name};
f=f(find(~strcmp(f,'handles')));
for i=1:length(f)
    eval(['handles.data.numberingParams.(f{i})=' f{i} ';']);
end
end

%% BASELINE FUNCTIONS

function grabBaseline(varargin)
handles = guidata(varargin{1});
f=fieldnames(handles.data.Params);
for i=1:length(f)
    eval(sprintf('%s=deal(handles.data.Params.(f{i}));',f{i}));
end


points_needed4baseline = sampling_rate*time2collectBaseline*number_of_channels *num_freq_bands;
number_of_points2read = sampling_rate*number_of_sec2read*number_of_channels*num_freq_bands;
ANnumber_of_points2read = sampling_rate*number_of_sec2read*ANnumber_of_channels;
num_avgEvent_freqs2plot = length(avgEvent_freqs2plot);
num_singleEvent_freqs2plot = length(singleEvent_freqs2plot);

% LOAD DATA
if handles.simFlag==1
    % LOAD BASELINE DATA FROM HTK FILES ON DISK
    handles.data.Params.baselinePath=uigetdir;
    [baseline,analog]=loadHTKData(handles.data.Params.baselinePath,handles.data.Params.number_of_electrodes_total,handles.data.Params.time2collectBaseline);
else    
%*************NEED TO CHECK BLOCK START*******************************   
    % COLLECT BASELINE DATA FROM TDT
    DA = actxcontrol('TDevAcc.X');
    for i=1:length(dproj_name)
        BufferSize(i)=DA.GetTargetSize(dproj_name{i});% returns the Buffer size (bookkeeping)
    end
    
    oldAcqPos=BufferSize;
    DA.SetSysMode(2);

    baseline=grabTDTBaseline(time2collectBaseline, ...
        sproj_name,dproj_name, points_needed4baseline, BufferSize, DA, number_of_channels, ...
        num_freq_bands, sampling_rate,number_of_sec2read);
%*************NEED TO CHECK BLOCK END*******************************   
end

% DETECT BAD CHANNELS
badChannels=detectBadChannels(baseline.data);
handles.data.baselineStats.badChannels=badChannels;

% SUBTRACT CAR AND CALCULATE STFT
baseline=subtractCAR_16ChanBlocks(baseline,badChannels,baseline);
baselineSTFT=calcSTFT(baseline.data,baseline.sampFreq,[]);

% GET PARAMETER VALUES BASED ON BASELINE DATA
handles.data.baselineStats.sampPerSecond=size(baselineSTFT.data,3)/handles.data.Params.time2collectBaseline;
handles.data.baselineStats.avgEvent_freqs2plot = 1:size(baselineSTFT.data,2);
handles.data.baselineStats.singleEvent_freqs2plot = handles.data.Params.avgEvent_freqs2plot;
handles.data.baselineStats.num_avgEvent_freqs2plot = length(handles.data.Params.avgEvent_freqs2plot);
handles.data.baselineStats.num_singleEvent_freqs2plot = length(handles.data.Params.singleEvent_freqs2plot);
handles.data.baselineStats.num_freq_bands = length(handles.data.Params.avgEvent_freqs2plot);
handles.data.baselineStats.desired_freq_plot=find(baselineSTFT.freq>70 & baselineSTFT.freq<150);

% GET BASELINE STATS
handles.data.baselineStats.medians=median(baselineSTFT.data,3);
handles.data.baselineStats.averages=mean(baselineSTFT.data,3);
handles.data.baselineStats.stdevs=std(baselineSTFT.data,[],3);

% SAVE BASELINE STATS TO DISK--- TO BE DELETED
% [filename,pathname]=uiputfile;
% baselineStats=handles.data.baselineStats;
% handles.userInput.baselinePath=[pathname filesep filename];
% save(handles.userInput.baselinePath,'baselineStats');
% set(handles.gui.userInput.baselineChoice,'String',handles.userInput.baselinePath);

guidata(gcf,handles);
end

%% COLLECT TDT DATA FUNCTIONS
%*********************NEED TO CHECK ALL OF THESE**************************
function baseline=grabTDTBaseline(time2collectBaseline, ...
    sproj_name,dproj_name, points_needed4baseline, BufferSize, DA, num_channels, num_freq_bands,...
    sampling_rate, number_of_sec2read)

h = waitbar(0,'Calculating Baseline...');
for i = 1:time2collectBaseline
    pause(1);
    waitbar(i/(time2collectBaseline+1),h)
end
pause(1);
AcqPos=AcquirePosition(sproj_name, BufferSize, DA);
AcqPos = AcqPos - points_needed4baseline+BufferSize(1);
AcqPos = mod(AcqPos,BufferSize(1));

BaselineData =readTarget(dproj_name,AcqPos, points_needed4baseline, DA);
% converts to matrix
% reshape to chan x freq x time
BaselineDataMAT=[];
num_freq_bands=1;
for i = 1:size(BaselineData,1)
    BaselineDataMAT= [BaselineDataMAT; shiftdim(reshape(reshape(BaselineData(i,:),...
        num_freq_bands*num_channels, sampling_rate*time2collectBaseline)',...
        sampling_rate*time2collectBaseline,num_channels,num_freq_bands),1)];
end

medians = median(BaselineDataMAT,3);
%logBaselineDataMAT = log(BaselineDataMAT+repmat(medians,[1 1 size(BaselineDataMAT,3)])+eps);

stdevs=[];
medians=[];
averages=[];
logBaselineDataMAT=[];
%medians=repmat(medians,[1 1 (sampling_rate*number_of_sec2read)]);
%averages = repmat(mean(logBaselineDataMAT,3),[1 1 (sampling_rate*number_of_sec2read+1)]);
%stdevs = repmat(std(logBaselineDataMAT,0,3),[1 1 (sampling_rate*number_of_sec2read+1)]);
%averages = repmat(mean(logBaselineDataMAT,3),[1 1 (sampling_rate*1+1)]);
%stdevs = repmat(std(logBaselineDataMAT,0,3),[1 1 (sampling_rate*1+1)]);
waitbar(1,h,'Baseline Statistics Gathered!')
pause(1)
close(h)
baseline.data=BaselineDataMAT;
baseline.sampFreq=sampling_rate;
end

function  [NewDataMAT,ANNewData,ANAcqPos,AcqPos,bufferCounter, ...
    constant, ANconstant, posInNewData_AfterCAR, ANposInNewData,number_of_points2read,ANnumber_of_points2read]=...
    getTDTData(DA,matlab_loopCounter,bufferCounter,ANbufferCounter,...
    number_of_points2read, ANnumber_of_points2read,sproj_name,dproj_name,sANproj_name,dANproj_name,...
    BufferSize,ANBufferSize, oldAcqPos, ANoldAcqPos,number_of_channels,ANnumber_of_channels, constant,ANconstant)

if matlab_loopCounter ~= 0
    AcqPos = oldAcqPos+number_of_points2read;
    AcqPos = mod(AcqPos,BufferSize(1));
    tmp=AcquirePosition(sproj_name, BufferSize, DA);
    number_of_points2read = tmp(1)-AcqPos(1);
    if number_of_points2read<0
        number_of_points2read = BufferSize(1) - AcqPos(1)+tmp(1);
    end
else
    AcqPos=AcquirePosition(sproj_name, BufferSize, DA) - number_of_points2read +BufferSize(1);
    AcqPos = mod(AcqPos,BufferSize(1));
end
num_freq_bands = 1;
bufferCounter=updateCounter(bufferCounter, AcqPos, oldAcqPos);
posInNewData_AfterCAR=findPosition(bufferCounter,BufferSize, AcqPos, ...
    number_of_channels*num_freq_bands);
if matlab_loopCounter~=0
    posInNewData_AfterCAR=posInNewData_AfterCAR-constant;
else
    % first position may be late in the buffer,
    % this sets intial matlab buffer index to one
    constant = posInNewData_AfterCAR-1;
    posInNewData_AfterCAR = ones(size(posInNewData_AfterCAR));
end

% Repeat for Analog channels
if matlab_loopCounter ~= 0
    ANAcqPos = ANoldAcqPos+ANnumber_of_points2read;
    ANAcqPos = mod(ANAcqPos,ANBufferSize);
    tmp=AcquirePosition(sANproj_name, ANBufferSize, DA);
    ANnumber_of_points2read = tmp(1)-ANAcqPos(1);
    if ANnumber_of_points2read<0
        ANnumber_of_points2read = ANBufferSize - ANAcqPos(1)+tmp(1);
    end
else
    ANAcqPos=AcquirePosition(sANproj_name, ANBufferSize, DA) - ANnumber_of_points2read+ ANBufferSize;
    ANAcqPos = mod(ANAcqPos,ANBufferSize);
end

ANbufferCounter = updateCounter(ANbufferCounter, ANAcqPos, ANoldAcqPos);
ANposInNewData=findPosition(ANbufferCounter, ANBufferSize, ANAcqPos, ANnumber_of_channels);
if matlab_loopCounter~=0
    ANposInNewData=ANposInNewData-ANconstant;
else
    ANconstant = ANposInNewData-1;
    ANposInNewData = ones(size(ANposInNewData));
end
ANNewData = DA.ReadTargetVEX(dANproj_name{1},ANAcqPos, ANnumber_of_points2read,'F32','F64');
ANNewDataMAT=reshape(ANNewData,ANnumber_of_channels,ANnumber_of_points2read/ANnumber_of_channels);

% Read from TDT buffers and reshape to chan x freq bands x time
NewData=readTarget(dproj_name, AcqPos, number_of_points2read, DA);
NewDataMAT=zeros(number_of_channels*length(AcqPos),num_freq_bands,number_of_points2read/(num_freq_bands*number_of_channels));
for i = 1:size(NewData,1)
    ind = (i-1)*number_of_channels+1;
    NewDataMAT( ind:(ind+number_of_channels-1),:, :) =shiftdim(reshape(reshape(NewData(i,:),...
        num_freq_bands*number_of_channels, number_of_points2read/(num_freq_bands*number_of_channels))',...
        number_of_points2read/(num_freq_bands*number_of_channels),number_of_channels,num_freq_bands),1);
end

end

function  NewData=readTarget(dproj_name,AcqPos, number_of_points2read, DA)
for i = 1:length(AcqPos)
    NewData(i,:)=DA.ReadTargetVEX(dproj_name{i},AcqPos(1), number_of_points2read,'F32','F64');
end
end

function AcqPos = AcquirePosition(sproj_name, BufferSize, DA)

for i = 1:length(sproj_name)
    AcqPos(i)=DA.GetTargetVal(sproj_name{i});%DA.GetTargetVal(sproj_name{i})-number_of_points2read+BufferSize(i);
    %AcqPos(i) = mod(AcqPos(i),BufferSize(i)); %%
    % + BufferSize takes care of circular buffer, prevents tdt from getting
    % confused over a negative position ( -number_of_points2read)
end
end

function newbufferCounter = updateCounter(bufferCounter, AcqPos, oldAcqPos)
for i=1:length(AcqPos)
    newbufferCounter(i)=bufferCounter(i)+(AcqPos(i)<oldAcqPos(i));
end
end

function [posInNewData] = findPosition(bufferCounter, BufferSize, AcqPos, number_of_channels)

for i=1:length(BufferSize)
    posInNewData(i) = (bufferCounter(i)*BufferSize(i)+AcqPos(i)-BufferSize(i))/number_of_channels;
end
end

%% LOAD HTK FUNCTIONS

function  [ecog,analog]=loadHTKData(filepath,number_of_electrodes_total,number_of_sec2read)
if ~isempty(number_of_sec2read)
    time=[1 (number_of_sec2read*1000)];
else
    time=[];
end
filenames=getFileNames('blocks',1:number_of_electrodes_total);
if isdir([filepath filesep 'Downsampled400'])
    ecog=loadHTKFile_Name([filepath filesep 'Downsampled400'],filenames,time);
elseif isdir([filepath filesep 'RawHTK'])
    ecog=loadHTKFile_Name([filepath filesep 'RawHTK'],filenames,time);    
    ecog=downsampleEcog(ecog,400,ecog.sampFreq);
end
analog=loadHTKFile_Name([filepath filesep 'Analog'],{'ANIN1','ANIN2','ANIN3','ANIN4'},time);
analog=downsampleEcog(analog,400,analog.sampFreq);
for i=1:size(analog.data,1)
    analog.data(i,:)=zscore(abs(hilbert(analog.data(i,:))));
end
end

function [ecog,analog,currentTime]=grabDataBuffer(ecogAll,analogAll,lastTime)
if lastTime==0
    elapsedTime=2;
else
    elapsedTime=toc;
end
tic;
samps=[round(lastTime*ecogAll.sampFreq)+1:round((lastTime+elapsedTime)*ecogAll.sampFreq)];
ecog.data=ecogAll.data(:,samps);
ecog.sampFreq=ecogAll.sampFreq;
analog.data=analogAll.data(:,samps);
analog.sampFreq=analogAll.sampFreq;
currentTime=lastTime+elapsedTime;
end


%% SEGMENTATION FUNCTIONS

function [num_events,indLastEvent,eventTimes,new_event_flag] = parseEvents(ANNewData_finalMAT, ANfinalPos, desired_ANchan,...
    desired_ANchan2, threshold, threshold2, sampling_rate, last_num_events,...
    indLastEvent, eventTimes, number_of_analog,window_before_event)
% num_events is number after rejection based off of timing of events
num_events = last_num_events;
event=(ANNewData_finalMAT(desired_ANchan,:)>threshold);
trigger1=[(diff(event)>0) 0];
detected_num_events = sum(trigger1);

if number_of_analog==1
    ind = find(trigger1,detected_num_events);
    ind(find([0 diff(ind)<(sampling_rate*1)]))=[]; %ignore events within 1sec of each other
    indLastEvent = [];
    %eventIndices(1,1:length(ind))=ind;
    eventTimes=ind/sampling_rate;
    num_events = length(ind);
else % number_of_analog==2
    
    event=(ANNewData_finalMAT(desired_ANchan2,:)>threshold2);
    trigger2=[2*(diff(event)>0) 0];
    
    triggers = trigger1+trigger2; %this takes care of when 2 events happen at the same time
    
    while indLastEvent<ANfinalPos
        % find onset of 1st events (starting from last event recorded) for the first two trials
        event1onset = find([zeros(1,indLastEvent) triggers(indLastEvent+1:ANfinalPos)]==1,2);
        if ~isempty(event1onset)
            %find 2nd event that occurs after 1st event
            event2onset =  find([zeros(1,event1onset(1)) triggers(event1onset(1)+1:ANfinalPos)]==2,1);
            
            %find previous trial's 1st and 2nd event
            latest1eventonset= find(triggers(1:event1onset(1)-1)==1);
            if ~isempty(latest1eventonset)
                latest1eventonset = latest1eventonset(end);
            else
                latest1eventonset = -1*sampling_rate;
            end
            latest2eventonset = find(triggers(1:event1onset(1))==2);
            if ~isempty(latest2eventonset)
                latest2eventonset = latest2eventonset(end);
            else
                latest2eventonset = -1*sampling_rate;
            end
            %end
        else
            event2onset=[];
        end
        
        if isempty(event2onset) || isempty(event1onset) %no events found
            break;
            % indLastEvent = ANfinalPos;
        elseif length(event1onset)~=2 % 2nd trial was not found
            break;
        elseif (event2onset-event1onset(1))<=2*sampling_rate && (event2onset-event1onset(1))>0 && ...
                (event1onset(2)-event2onset)>=1*sampling_rate && ...
                (event1onset(1)-latest2eventonset)>=1*sampling_rate &&...
                (event1onset(1)-latest1eventonset)>=1*sampling_rate &&...
                (event1onset(1)>window_before_event)% Takes care of not enough data before the first event
            % 2nd event occured within 0-2 seconds of 1st event
            % 2nd trial occured after 1 second of 2nd event
            % 1st event occured after 1 second of previous trial's 2nd event
            % 1st event occured after 1 second of previous trial's 1st event
            num_events = num_events+1;
            eventIndices(:,num_events) = [event1onset(1); event2onset; event2onset-event1onset(1)];
            indLastEvent = event1onset(1);
            
        else
            % next interation will look for events only after 2nd trial
            indLastEvent = event1onset(2)-1;
        end
    end
end

if num_events>last_num_events
    new_event_flag=1;
else
    new_event_flag=0;
end
end

function [averageSpec,num_samples,last_used_ind,allStacked,new_plot_flag,currentEvent,lastSpec] = average_event_window(num_events, eventTimes, window_around_event,...
    DataAfterCAR,AmountOfData,number_electrodes ,num_freq_bands, freqs2plot,...
    old_average, old_num_samples, last_used_ind,allStacked,good_event_count, averages, stdevs,freq_band_singlestacked,specTimes)
lastSpec=[];
%allocate memory, set up counter
current_num_events=num_events;
% average = zeros(number_electrodes,num_freq_bands, window_around_event+1);
%sum_windows = zeros(number_electrodes,num_freq_bands, window_around_event+1);
num_samples = 0;
ind=findNearest(eventTimes,specTimes);
if isempty(find(ind==last_used_ind))
    x=0;
else
    x=find(ind==last_used_ind);
end
new_plot_flag=0;
%loop over each event, grab corresponding window
currentEvent=x+1;
for  i=currentEvent:current_num_events
    beginning = ind(i) - floor(window_around_event/2);
    last = ind(i)+ ceil(window_around_event/2);
    if beginning <1 || last>AmountOfData
        continue; %since can't add different sized window, just ignore
    else
        timepts = beginning:last;
        lastSpec=(DataAfterCAR(:,freqs2plot, timepts)-averages)./stdevs;
        %sum_windows = sum_windows + DataAfterCAR(:,freqs2plot, timepts);
        num_samples = num_samples + 1;
        %last_used_ind = ind(currentEvent);
        lastSpec = artifactrejection(lastSpec, window_around_event,-5.5, 5.5, .5, .8);
        allStacked(:,currentEvent,:,:)=lastSpec;
        if isempty(old_average)
            old_average=lastSpec;
        else
            old_average=squeeze(nansum(cat(4,old_average.*currentEvent,lastSpec),4))./(currentEvent+1);
        end
         new_plot_flag=1;
        currentEvent=currentEvent+1;
    end
end;
currentEvent=currentEvent-1;
averageSpec=old_average;
end


function [average,last_used_ind,allStacked,new_plot_flag, plotted_num_events,lastSpec,lastSpec_event2,average_event2,event_indices] =...
    average_event_window_2_events(num_events, event_indices, window_before_event,window_after_event,...
    DataAfterCAR,AmountOfData,number_electrodes ,num_freq_bands, freqs2plot,...
    old_average, last_used_ind,allStacked,averages, stdevs,old_average_event2,freq_band_singlestacked,plotted_num_events)
%allStacked is the single stacked variable where each trial is sorted by
%latency of response. Aligned at event1, and includes event2
%old_average_event2 is updated average spectrogram aligned at event2
lastSpec=[];
lastSpec_event2=[];
window_around_event=window_before_event+window_after_event;

ind=event_indices(1,:);
latency=event_indices(2,:)-ind;
%allocate memory, set up counter
%current_num_events=good_event_count;
sum_windows = zeros(number_electrodes,num_freq_bands, window_before_event*2+1);
sum_windows_event2 = zeros(number_electrodes,num_freq_bands, window_before_event*2+1);

if isempty(old_average)
    old_average = zeros(number_electrodes,num_freq_bands, window_before_event*2+1);
    old_average_event2=zeros(number_electrodes,num_freq_bands, window_before_event*2+1);
end


%Finds event segments within bounds of available data
startidx=plotted_num_events+1;
beginning = ind(startidx) - window_before_event;
endidx=num_events;
last = event_indices(2,endidx)+ window_before_event;
last2 = ind(endidx)+ window_after_event;
while((last>AmountOfData) | (last2>AmountOfData)) & endidx>=startidx% what if ind(num_events-1)+window/2 is still out of bounds?
    last = event_indices(2,endidx)+ window_before_event;
    last2 = ind(endidx)+ window_after_event;
    endidx=num_events-1;
end

%If there are new events within the bounds of current data
%do i even need this? will endidx always be >= startidx?
if endidx>=startidx
    %loop over each event, grab corresponding window
    for i=[startidx:endidx]
        beginning = ind(i) - window_before_event;
        last = ind(i)+ window_after_event; % NOTE: need different last for stacked, see ln 761.
        %I think we should grab 2.5seconds after the first event
        %new_count=new_count+1;
        timepts = beginning:last;
        lastSpec=DataAfterCAR(:,freqs2plot, timepts);
        last_used_ind = ind(i);
        %prev_num_events=prev_num_events+1;
        lastSpec=(lastSpec-averages)./stdevs;
        sum_windows = sum_windows + lastSpec(:,:,1:window_before_event*2+1);
        
        allStacked(:,i,:)=lastSpec(:,freq_band_singlestacked,:);
        
        %Get data aligned at 2nd event
        beginning = event_indices(2,i) - window_before_event;
        last = event_indices(2,i)+ window_before_event;
        timepts = beginning:last;
        
        lastSpec_event2=(DataAfterCAR(:,freqs2plot, timepts)-averages(:,:,1:2*window_before_event+1))./stdevs(:,:,1:2*window_before_event+1);
        sum_windows_event2 = sum_windows_event2 + lastSpec_event2;
        
    end;
    %sort stacked plots by latency
    latency2=latency(1:endidx);
    [~,sortedidx]=sort(latency2);
    allStacked=allStacked(:,sortedidx,:);
    event_indices(:,1:endidx)=event_indices(:,sortedidx);
    
    
    %update average
    %current_num_event=prev_num_events;
    average = (old_average*plotted_num_events + sum_windows)/(num_events);
    average_event2 = (old_average_event2*prev_num_events + sum_windows_event2)/(num_events);
    new_plot_flag=1;
    
    plotted_num_events=endidx;%Need to check if this is right
    
else
    %if no new events, plotted_num_events does not increment
    %num_events=prev_num_events;
    average = old_average;
    average_event2=old_average_event2;
    new_plot_flag=0;
end
end

%% TIME/FREQUNECY TRANSFORMATION FUNCTIONS
function [ecogOut,nextRawIdx]=calcSTFT(data,sampFreq,nextRawIdx)
wl=2^nextpow2(fix(.05*sampFreq));
% for cidx=1:size(data,1)
%     [YY,tt,ff]=stft_hann_(data(cidx,:)',sampFreq,wl);
%     ecogOut.data(cidx,:,:)=(abs(YY));
% end
%[YY,tt,ff,wss,wl]=stft_multi_ECoG(data',sampFreq);
[YY,tt,ff,wss]=stft_hann_allChan(data',sampFreq,wl);
ecogOut.data=abs(YY);
ecogOut.time=tt;
ecogOut.freq=ff;
ecogOut.data=permute(ecogOut.data,[3,1,2]);
if ~isempty(wss)
    nextRawIdx=wss(end)+wl/2+nextRawIdx-1;
else
    nextRawIdx=nextRawIdx;
end
end

%% ARTIFACT REJECTION FUNCTIONS

function badChannels=detectBadChannels(data)
%badChannels=find(zscore(mean(data,2))>5);
for c=1:size(data,1)
    %p(c,:)=log10(smooth(periodogram(data(c,:))',200));
    p(c,:)=log10((periodogram(data(c,:))'));
end
badChannels=find(zscore(mean(abs((p-repmat(mean(p),256,1)))'))>3);
end

function lastSpec = artifactrejection(lastSpec, window_around_event,...
    min_zscore, max_zscore, percentage_min, percentage_max, to_plot_grid)
%reshaped data = freqs2plot*8 x window_around_event+1*8
%
%  if more than percentage_min% of the data is below min_zscore, reject
%  if more than percentage_max%of the data is above max_zscore, reject

[a,b]=find(abs(mean(lastSpec,3))>max_zscore);
for i=1:length(a)
    lastSpec(a(i),b(i),:)=NaN;
end
end
%% MISC FUNCTIONS

function to_plot = reshape_3Ddata(to_reshape, window_around_event,...
    num_freq_bands, to_plot_grid)
%to_reshape = chan x freq x timepts
to_plot = zeros(num_freq_bands*to_plot_grid, to_plot_grid*(window_around_event+1));

beginning = 0;
for i = 0:(to_plot_grid-1)  %ASSUMES to_plot_grid x to_plot_grid CHANNELS
    last =  beginning+to_plot_grid*(window_around_event+1);
    data = to_reshape(i*to_plot_grid+1:i*to_plot_grid+to_plot_grid,:,:);
    to_plot(i*num_freq_bands+1:i*num_freq_bands+num_freq_bands,:) = ...
        flipud(reshape(shiftdim(data,1),num_freq_bands, to_plot_grid*(window_around_event+1)));
    beginning = last;
    %Grab every eight channels and form to_plot_grid x to_plot_grid square
end
end

function loadMRI(varargin)
    handles=guidata(varargin{1});
    [filename,pathname]=uigetfile('*.jpg');
    im=imread([pathname filename]);
    load([pathname 'regdata.mat']);
    for m=1:4
        handles.gui.mri(m).plot=[];
        handles.gui.mri(m).im=[];
        handles.gui.xy(m).xy=[];        
        handles.gui.mri(m)=plotMRI(handles.gui.mri(m),'initiate',im,xy);
        set(handles.gui.mri(m).handle,'visible','on');
    end
    guidata(handles.gui.fig,handles);
end

function displayGUIHelp(varargin)
% READS .TXT FILE IN SAME FOLDER AS FUNCTION AND DISPLAYS IT IN A HELP
% DIALOG
[folderPath,b]=fileparts(which(mfilename));
fid = fopen([folderPath filesep 'guihelp.txt'], 'r');
c =  fscanf(fid,'%c');
helpdlg(c)
end

