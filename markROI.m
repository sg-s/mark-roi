% markROI.m
% marks rois in an image sequecne
% 
% created by Srinivas Gorur-Shandilya at 12:17 , 03 December 2015. Contact me at http://srinivas.gs/contact/
% 
% This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. 
% To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.ts
function [] = markROI()

% file-wide variables
handles = struct;
images = [];
nframes = [];
cmax = 255;
cmin = 0;
current_file = 1;

control_roi = [];
test_roi = [];

% first, get the directory we are going to work in
folder_name = uigetdir;
folder_name = [folder_name oss];

% get all image files in this
allfiles = dir([folder_name 'video_*.mat']);

% make the UI
makeUI;

% load the first file
loadFile(1);



function makeUI
    handles.fig = figure('outerposition',[100 50 600 800],'NumberTitle','off','Name','markROI','Toolbar','none','Menubar','none');
    handles.ax1 = axes('parent',handles.fig,'Position',[0.05 0.3 0.9 0.65]); hold on
    colormap hot
    handles.scrubber = uicontrol(handles.fig,'Units','normalized','Position',[.05 .15 .9 .1],'Style', 'slider','FontSize',12,'Callback',@showFrame);
    try    % R2013b and older
       addlistener(handles.scrubber,'ActionEvent',@showFrame);
    catch  % R2014a and newer
       addlistener(handles.scrubber,'ContinuousValueChange',@showFrame);
    end

    handles.next_file = uicontrol(handles.fig,'Units','normalized','Position',[.90 .01 .1 .05],'Style', 'pushbutton','FontSize',12,'String','>','Callback',@loadFile);
    handles.prev_file = uicontrol(handles.fig,'Units','normalized','Position',[.0 .01 .1 .05],'Style', 'pushbutton','FontSize',12,'String','<','Callback',@loadFile);

    handles.max_proj = uicontrol(handles.fig,'Units','normalized','Position',[.05 .15 .15 .05],'Style', 'pushbutton','FontSize',12,'String','Max. Proj.','Callback',@maxProj);

    handles.std_proj = uicontrol(handles.fig,'Units','normalized','Position',[.25 .15 .15 .05],'Style', 'pushbutton','FontSize',12,'String','Std. Proj.','Callback',@stdProj);

    handles.mark_control = uicontrol(handles.fig,'Units','normalized','Position',[.65 .15 .15 .05],'Style', 'pushbutton','FontSize',12,'String','+Control ROI.','Callback',@pickROI);
    handles.mark_test = uicontrol(handles.fig,'Units','normalized','Position',[.80 .15 .15 .05],'Style', 'pushbutton','FontSize',12,'String','+Test ROI','Callback',@pickROI);


end


function pickROI(src,~)
    h = imfreehand;
    if any(strfind(src.String,'ontrol'))
        control_roi(:,:,end+1) = createMask(h,handles.im);
    else
        test_roi(:,:,end+1) = createMask(h,handles.im);
    end

    % save to file
    save([folder_name allfiles(current_file).name],'control_roi','test_roi','-append');

end

function maxProj(~,~)
    temp = max(images,[],3);
    handles.im = imagesc(temp);
    caxis([min(min(temp)) max(max(temp))])
end

function stdProj(~,~)
    temp = std(images,[],3);
    handles.im = imagesc(temp);
    caxis([min(min(temp)) max(max(temp))])
end
    
function loadFile(src,event)
    cla(handles.ax1)
    images = []; 
    control_roi = [];
    test_roi = [];
    set(handles.fig,'Name','Loading...')
    if src ~= 1
        if strcmp(src.String,'>')
            load_this = current_file + 1;
        elseif strcmp(src.String,'<')
            load_this = current_file - 1;
        end
        current_file = load_this;
    else
        load_this = src;
        current_file = 1;
    end

    if current_file == length(allfiles)
        set(handles.next_file,'Enable','off')
        set(handles.prev_file,'Enable','on')
    elseif current_file == 1
        set(handles.next_file,'Enable','on')
        set(handles.prev_file,'Enable','off')
    else
        set(handles.next_file,'Enable','on')
        set(handles.prev_file,'Enable','on')
    end

    temp = load([folder_name allfiles(load_this).name]);
    disp([folder_name allfiles(load_this).name]);
    images = temp.images;

    % determine the number of frames
    nframes = size(images,3);
    set(handles.scrubber,'Min',1,'Max',nframes,'Value',1);

    set(handles.ax1,'XLim',[1 size(images,1)],'YLim',[1 size(images,2)])

    % show pre-existing ROIs is present
    if any(find(strcmp('control_roi',fieldnames(temp))))
        control_roi = temp.control_roi;
    else
        control_roi = zeros(size(images,2),size(images,2),0);
    end

    if any(find(strcmp('test_roi',fieldnames(temp))))
        test_roi = temp.test_roi;
    else
        test_roi = zeros(size(images,2),size(images,2),0);
    end

    showFrame;


end

function showFrame(~,~)
    this_image = images(:,:,ceil(get(handles.scrubber,'Value')));

    this_image = this_image -  min(min(min(images)));
    this_image = this_image/( max(max(max(images)))- min(min(min(images))));

    % mask out the control and test rois, if any.
    this_image(:,:,2) = mean(mean(mean(images))).*(sum(control_roi,3));
    this_image(:,:,3) = mean(mean(mean(images))).*(sum(test_roi,3));


    handles.im = imagesc(this_image);

    % set(handles.fig,'Name',['[' mat2str(min(min(this_image))) '-' mat2str(max(max(this_image))) ']'])

    % try to pick a nice colourmap
    cmax = max(.9*max(max(max(images))));
    cmin = min(min(min(images)));
    caxis([cmin cmax]);

end

end
