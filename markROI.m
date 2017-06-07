% markROI.m
% marks rois in an image sequence
% will work on .mat files that contain a variable called "images" that is a 3D matrix (monochrome images only)
% .mat files should be v7.3 or later, as markROI only partially loads files to speed up the UI
% 
% 
% created by Srinivas Gorur-Shandilya at 12:17 , 03 December 2015. Contact me at http://srinivas.gs/contact/
% 
% This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. 
% To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.ts
classdef markROI < handle

properties
    handles = struct;
    nframes = [];
    current_file = 1;
    m = []; % matfile handle
    variable_name = 'images';
    folder_name
    allfiles



end % end properties 


methods

    function markROI(m)

        % first, get the directory we are going to work in
        folder_name = uigetdir(pwd,'Choose a folder containing .mat files of the videos you want to work on');
        m.folder_name = [folder_name oss];

        % get all image files in this
        m.allfiles = dir([m.folder_name '*.mat']);
        % remove files that begin with a dot
        m.allfiles(cellfun(@(x) strcmp(x(1),'.'),{m.allfiles.name})) = [];

        assert(length(m.allfiles)>0,'No files found! Make you are in a folder with some .mat files"')

        % make the UI
        m.makeUI;

        % load the first file
        loadFile(m,1);

    end % end creator function 

end % end methods 





function makeUI(m,~,~)
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

    handles.timeseries_button = uicontrol(handles.fig,'Units','normalized','Position',[.05 .09 .3 .05],'Style', 'togglebutton','FontSize',12,'String','Show time series','Callback',@drawOrEraseTimeSeriesPlot);

    handles.mark_control = uicontrol(handles.fig,'Units','normalized','Position',[.65 .15 .15 .05],'Style', 'pushbutton','FontSize',12,'String','+Control ROI.','Callback',@pickROI);
    handles.mark_test = uicontrol(handles.fig,'Units','normalized','Position',[.80 .15 .15 .05],'Style', 'pushbutton','FontSize',12,'String','+Test ROI','Callback',@pickROI);


end

function drawOrEraseTimeSeriesPlot(src,~)
    if src.Value == 1
        src.String = 'Hide time series';
        % now make the UI for the time series
        handles.timeseries_fig = figure('outerposition',[700 300 800 500],'NumberTitle','off','Name','Time series');
        handles.timeseries_ax = axes(handles.timeseries_fig);
        hold(handles.timeseries_ax,'on')
        xlabel(handles.timeseries_ax,'Frame #')
        ylabel(handles.timeseries_ax,'Intensity (a.u.)')
        set(handles.timeseries_ax,'XLim',[1 nframes])

        % plot the time series
        variable_names = whos(m);
        I = m.(variable_name);
        if any(strcmp({variable_names.name},'control_roi'))
            control_roi = m.control_roi;
            for i = 1:size(control_roi,3)
                plot(handles.timeseries_ax,squeeze(sum(sum(repmat(control_roi(:,:,i),1,1,nframes).*I))),'k');
            end
        end
        if any(strcmp({variable_names.name},'test_roi'))
            test_roi = m.test_roi;
            for i = 1:size(test_roi,3)
                plot(handles.timeseries_ax,squeeze(sum(sum(repmat(test_roi(:,:,i),1,1,nframes).*I))),'r');
            end
        end
    else
        src.String = 'Show time series';
        try
            delete(handles.timeseries_fig)
        catch
        end
    end
end


function pickROI(src,~)
    h = imfreehand;
    if any(strfind(src.String,'ontrol'))
        try
            m.control_roi(:,:,end+1) = createMask(h,handles.im);
        catch
            [a,b] = size(createMask(h,handles.im));
            m.control_roi = logical(zeros(a,b,2));
            m.control_roi(:,:,1) = createMask(h,handles.im);
        end
    else
        try
            m.test_roi(:,:,end+1) = createMask(h,handles.im);
        catch
            [a,b] = size(createMask(h,handles.im));
            m.test_roi = logical(zeros(a,b,2));
            m.test_roi(:,:,1) = createMask(h,handles.im);
        end
    end

    % % save to file
    % save([folder_name allfiles(current_file).name],'control_roi','test_roi','-append');

end

function maxProj(~,~)
    temp = max(m.(variable_name)(:,:,1:50:get(handles.scrubber,'Max')),[],3);
    handles.im = imagesc(temp);
    caxis([min(min(temp)) max(max(temp))])
end

function stdProj(~,~)
    temp = std(m.(variable_name)(:,:,1:50:get(handles.scrubber,'Max')),[],3);
    handles.im = imagesc(temp);
    caxis([min(min(temp)) max(max(temp))])
end
    
function loadFile(src,~)
    cla(handles.ax1)
    set(handles.fig,'Name','markROI')
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

    % check if the current file is v7.3; if not, convert it
    if findMATFileVersion([folder_name allfiles(load_this).name]) ~= 7.3
        convertMATFileTo73([folder_name allfiles(load_this).name])
    end


    m = matfile([folder_name allfiles(load_this).name],'Writable',true);
    set(handles.fig,'Name',allfiles(load_this).name);

    % figure out which variable to load
    variable_names = whos(m);
    if length(variable_names) == 1
        variable_name = variable_names(1).name;
    else
        % only retain 3D arrays
        variable_names = variable_names(cellfun(@length,{variable_names.size}) == 3);
        % pick the largest one
        variable_name = variable_names(find([variable_names.bytes] == max([variable_names.bytes]))).name;
    end

    % determine the number of frames
    [a,b,nframes] = size(m,variable_name);
    set(handles.scrubber,'Min',1,'Max',nframes,'Value',round(nframes/2));

    set(handles.ax1,'XLim',[1 a],'YLim',[1 b])

    showFrame;


end

function showFrame(~,~)
    this_image = m.(variable_name)(:,:,ceil(get(handles.scrubber,'Value')));

    % mask out the control and test rois, if any.
    try
        this_image(:,:,2) = (mean(mean(this_image(:,:,1)))).*(sum(m.control_roi,3));
    catch
        this_image(:,:,2) = 0*this_image(:,:,1);
    end
    try
        this_image(:,:,3) = (mean(mean(this_image(:,:,1)))).*(sum(m.test_roi,3));
        this_image(:,:,2) = .5*this_image(:,:,2) + .5*(mean(mean(this_image(:,:,1)))).*(sum(m.test_roi,3));
    catch
        this_image(:,:,3) = 0*this_image(:,:,1);
    end

    this_image = this_image - min(min(min(this_image)));
    this_image = 1.1*this_image/max(max(max(this_image)));
    handles.im = imagesc(this_image);

end

end