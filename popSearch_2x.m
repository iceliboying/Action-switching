function popSearch_2x(block)
% pop-out search task with color/orientation targets using a dimension
% discrimination task and testing for effects of different ratios of the dimensions

datapath= '.';

blk_trials = 50;
num_block = 30;
%    block_percent = [75 25 50];

rand('seed',sum(clock*100))

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Create an experiment structure with three blocks
% and num_block/3 subblocks in each full block
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
exp = CExp(num_block,blk_trials,'blockFactors',1,'blockRepetition',1); %
%    full_blk_trials = num_block*blk_trials/3; % Number of trials in a "full" block
exp.seq = genTrials(num_block/3,50,3); % color/ori/absent, pos
full_blk_trials=num_block*blk_trials/3; % Number of trials in a "full" block
    
for i=1:num_block
    seq=debruijn_generator(7,2);
    seq(end+1)=seq(1);
    exp.seq((i-1)*blk_trials+1:i*blk_trials,1)=seq<5; % seq %in% 5...8 => target absent
    exp.seq((i-1)*blk_trials+1:i*blk_trials,2)=mod(ceil(seq/2),2)+1; % response/action mapping (1 = cue on right, 2 = cue on left)
    exp.seq((i-1)*blk_trials+1:i*blk_trials,3)=mod(seq,2)+1; % seq odd => ori target, seq even => color target
    exp.seq((i-1)*blk_trials+1:i*blk_trials,4)=0; % target postion
end

% exp.subInfo; % acquire subject information

expInfo.NumTrials = size(exp.seq,1);
expInfo.myResp = zeros(expInfo.NumTrials,3); %  kb.response, rt, error
expInfo.curTrial = 1;
expInfo.TrialsInBlock = blk_trials;
expInfo.StartTime = GetSecs;

% parameters initialization: text, images.
% infoText = init_text; %instruction etc.

% declare hardware variables: display, keyboard, stimuli
v = [];
kb = [];
stim = [];

% curState stores the state of the experimental flow
% timeTag store time marker for each state changes.

curState = expState.Init_Exp;
timeTag = GetSecs;

setup(block);

% set up block function
    function setup(block)
        
        % create visual display (monitor)
        v = SDisplay('lineSpace',2,'skipSync',1, 'fontSize', 20, ...
            'lineWidth',60,'monitorSize',20, 'bgColor',[0 0 0],'fullWindow',0);
        
        % define input device
        kb = SInput('m');
        
        %create vertical line
        % Luminance: 36
        green = [0 238 65]; %.290, .569
        red = [255 170 255]; % .293,.220
        turquoise = [64, 224, 208]; % .221, 0.318
        
        stim.tex_dis = v.createShape('rectangle',0.15, 0.8,'color',turquoise);
%         stim.tex_cue = v.createShape('rectangle', 0.2, 0.2, 'color', turquoise);
%         stim.tex_cue2 = v.createShape('rectangle', 0.2, 0.2, 'color', green);
        stim.tex_tar(1) = v.createShape('rectangle',0.15, 0.8,'color',red);
        stim.tex_tar(2) = v.createShape('rectangle',0.15, 0.8,'color',green);
        stim.isFinished = 0;
        stim.trigger =0;
        
        % store local trial information
        stim.c_target = 0;
%         stim.c_action_mapping= 0;
        stim.c_cond = 0; % color/orientation
        stim.c_target_pos = 0; % target position
        stim.c_color = 0; % purple or green;
        stim.c_orient = 0; % left or right;
        
        % generate xy positions (circular)
        stim.xy(1,:) = [0 0]; %center
        stim.n1=6; stim.n2=8; stim.n3=12;
        num_items = [stim.n1 stim.n2 stim.n3]; % number of items at each ring
        icount = 1;
        for i=1:length(num_items)
            jitter = (rand-0.5)/12*pi;
            %        ecc = i*1.8; % 1.5 degree
            ecc = i*2.4; % 1.5 degree
            for k = 1:num_items(i)
                icount = icount + 1;
                theta = 2*pi/num_items(i)*(k-1/2)+(i==3)*pi/12; % + jitter + (rand-0.5)/36*pi;
                stim.xy(icount, :) = ecc*[cos(theta), sin(theta)];
            end
        end
        %    plot(xy(:,1),xy(:,2),'d');
        
        
        stim.itemSizes = [0.26 1.4]; % size in visual angle degree2 x and y
        
        
        % Register number of ports
        block.NumInputPorts  = 1;
        block.NumOutputPorts = 2;
        block.SetPreCompInpPortInfoToDynamic;
        block.SetPreCompOutPortInfoToDynamic;
        
        % Override input port properties
        block.InputPort(1).Dimensions        = 2;
        block.InputPort(1).DatatypeID  = 0;  % double
        block.InputPort(1).DirectFeedthrough = true;
        block.InputPort(1).SamplingMode = 'sample';
        
        % Override output port properties
        block.OutputPort(1).Dimensions       = 4; %TrialNo., RT, Resp, Finish Signal
        block.OutputPort(1).DatatypeID  = 0; % double
        block.OutputPort(1).SamplingMode = 'sample';
        
        % Port 2 for trigger
        block.OutputPort(2).Dimensions       = 1;
        block.OutputPort(2).DatatypeID  = 0; % double
        block.OutputPort(2).SamplingMode = 'sample';
        
        % Register parameters
        block.NumDialogPrms     = 0;
        
        % Register sample times
        %  [0 offset]            : Continuous sample time
        %  [positive_num offset] : Discrete sample time
        %
        %  [-1, 0]               : Inherited sample time
        %  [-2, 0]               : Variable sample time
        block.SampleTimes = [-1, 0]; % Inherited time
        
        block.SimStateCompliance = 'DefaultSimState';
        
        block.RegBlockMethod('Outputs', @Outputs);     % Required
        block.RegBlockMethod('Update', @Update);
        block.RegBlockMethod('Terminate', @Terminate); % Required
    end

% output ports
    function Outputs(block)
        block.OutputPort(1).Data = [stim.isFinished, expInfo.curTrial, expInfo.myResp(expInfo.curTrial,1:2)];
        block.OutputPort(2).Data = stim.trigger;
        stim.trigger = 0;
    end
    
    
    
    function Update(block)
        switch curState
            case expState.Init_Exp
                infoText.instruction=['Visual Search \n', ...
                    'In this experiment, you will see a display with vertical or oblique lines. ', ...
                    'Your task is to find if there is any pop-out target, which differs in color or orientation from the rest. \n ',...
                    'Please rest your left and right index fingers onto the left and right mouse buttons.\n',...
                    'The small square that is shown briefly on the left or the right side of the fixation point ',...
                    'before each line display appears indicates which mouse button to press if a ',...
                    'target is present.\n',...
                    'If the square appears on the LEFT side, please press the LEFT button if a target is PRESENT ',...
                    'and the RIGHT button if it is ABSENT.\n',...
                    'If the square appears on the RIGHT side, please press the RIGHT button if a target is PRESENT ',...
                    'and the LEFT button if it is ABSENT.\n',...
                    'Please try to respond as quickly and accurately as possible.\n',...
                    '\n when you are ready, press any key to continue'];
                v.dispText(infoText.instruction);
                if kb.response>0
                    curState = expState.Init_Exp_Wait; % move to new Block
                end
                
            case expState.Init_Exp_Wait
                v.dispText('New Block Start');
                if kb.response>0
                    curState = expState.New_Block_Wait;
                end
                
            case expState.New_Block_Wait
                
                if mod(expInfo.curTrial-1,full_blk_trials)==0
                    switch exp.seq((i-1)*full_blk_trials+1,2)
                        case 1
                            infoText.instruction=['Block 1\n', ...
                                'In this block, Please attend to Target Absent. ', ...
                                'You do not need to respond.\n',...
                                '\n when you are ready, please tell the experimenter'];
                            v.dispText(infoText.instruction);
                            stim.trigger=1111;
                        case 2
                            infoText.instruction=['Block 1\n', ...
                                'In this block, Please attend to Color Target. ', ...
                                'You do not need to respond.\n',...
                                '\n when you are ready, please tell the experimenter'];
                            v.dispText(infoText.instruction);
                            stim.trigger=2222;
                        case 3
                            infoText.instruction=['Block 1\n', ...
                                'In this block, Please attend to Orientation Target. ', ...
                                'You do not need to respond.\n',...
                                '\n when you are ready, please tell the experimenter'];
                            v.dispText(infoText.instruction);
                            stim.trigger=3333;
                    end
                    disp(stim.trigger);
                end
                if kb.response>0
                    curState = expState.Block_Wait;
                end
         
            case expState.Block_Wait;
                if kb.response>0
                    curState=expState.Init_Block;
                end
                
            case expState.Init_Block
                if kb.response>0
                    curState = expState.Init_Trial; % move to Trial presentation
                end
               
            case expState.Init_Trial
                % trial configration
                
                % 1. prepare stimuli at given condition(s)

                cond = exp.getCondition; %get condition array
disp(cond);
                stim.c_target = cond(1); % target present/absent
%                 stim.c_action_mapping = cond(2); % mapping between responses (present/absent) and actions (left mouse button/right mouse button)
                stim.c_cond = cond(3); % color/orientation
                stim.c_target_pos = 0; % target position
                stim.c_color = ceil(rand*2); % purple or green;
                stim.c_orient = ceil(rand*2); % left or right;

                stim.items = ones(1,length(stim.xy))*stim.tex_dis; %search items
                stim.rotations = zeros(1,length(stim.xy)); %rotation of the items
                %define target
                if stim.c_target == 1 % target present
                    stim.c_target_pos = 2+stim.n1+floor(stim.n2*rand);    
disp(stim.c_target_pos); 
                    if stim.c_target_pos<14 && stim.c_target_pos>9
                        exp.seq(expInfo.curTrial,4)= 1; % target Left
                    else
                        exp.seq(expInfo.curTrial,4)= 0; % target Right
                    end
                    switch stim.c_cond
                        case 1 % color
                            stim.items(stim.c_target_pos) = stim.tex_tar(stim.c_color);
                        case 2 % orientation
                            stim.rotations(stim.c_target_pos) = (stim.c_orient-1.5)*60;
                        case 3 % redundant (not used in this experiment)
                            stim.items(stim.c_target_pos) = stim.tex_tar(stim.c_color);
                            stim.rotations(stim.c_target_pos) = (stim.c_orient-1.5)*60;
                    end
                end
                % 2. display stimuli
                % 2.1 fixation

                %                 v.dispText(5,2,0);  %original codes
                %                 WaitSecs(0.3);      %original codes

                v.dispFixation(5,2);
                
                curState = expState.Fixation; % move to Fixation
                timeTag = GetSecs;
                stim.trigger = 1; % fixation trigger  ´% modify
                
            case expState.Fixation
                if GetSecs - timeTag > curState.duration
                    curState = expState.Cue_Wait;
                    timeTag = GetSecs;
                    t = exp.seq(expInfo.curTrial,1)*power(2,4) + floor(exp.seq(expInfo.curTrial,2)-1)*power(2,3) + (exp.seq(expInfo.curTrial,3)-1)*power(2,2) + exp.seq(expInfo.curTrial,4)*power(2,1) ; 
                    % Mark target present or absent on the 5th digit, cue 
                    % left or right on the 4th digit, color or orientation 
                    % on the 3rd digit, target left or right
                    % on the 2nd digit.
                    % The first digit is kept for response
                    stim.trigger = t;
disp(stim.trigger);
                end
                 
%             case expState.Cue
%                 cond = exp.getCondition; % get condition array
%                 if cond(2)==1
%                     v.dispItems([2 0], stim.tex_cue, [0.5 0.5], 0);
%                     %  v.dispItems([-2 0; 2 0], [tex_cue tex_cue2], [0.3 0.3; 0.3 0.3], 0);
%                 else
%                     v.dispItems([-2 0], stim.tex_cue, [0.5 0.5], 0);
%                     %  v.dispItems([2 0; -2 0], [tex_cue tex_cue2], [0.3 0.3; 0.3 0.3], 0);
%                 end
%                 
%                 curState = expState.Cue_Wait;
%                 timeTag = GetSecs;
%                 stim.trigger = exp.seq(expInfo.curTrial,2)-1; % cue position: 1-left, 0-right
%  disp('cue');disp(stim.trigger);               
            case expState.Cue_Wait
                 if GetSecs - timeTag > curState.duration
                     curState = expState.Target;
                     timeTag = GetSecs;
                 end
                 
            case expState.Target
            
                v.dispItems(stim.xy, stim.items, repmat(stim.itemSizes,length(stim.items),1),stim.rotations);
                curState = expState.End_Trial;
                timeTag = GetSecs;                  

%             case expState.Response
%                 
%                     resp = kb.response;
%                     if resp > 0
%                         v.flip;
%                         curState = expState.End_Trial;
%                         rt = GetSecs - timeTag;
%                         expInfo.myResp(expInfo.curTrial, 1:2) = [resp, rt];
%                         timeTag = GetSecs;
%                         stim.trigger = resp-1; % left 0, right 1      % send trigger to EEG
% disp(stim.trigger);
%                     end
                    
%             case expState.Feedback
%                 resp = expInfo.myResp(expInfo.curTrial, 1);
%                 correct=1;
%                 if ((stim.c_action_mapping==1 && mod(stim.c_target,2)==mod(resp,2)) || ...
%                         (stim.c_action_mapping==2 && mod(stim.c_target+1,2)==mod(resp,2)) )
%                     % change 'key' into kb.response,in the myversioninJune there is                    
%                     % '[key, rTime] = kb.response;', here there is not.          
% 
%                     v.color=[255 0 0];
%                     correct=0;
%                     v.dispText('Incorrect')
%                     v.color=[255 255 255];
%                     curState = expState.Feedback_Wait; % wait 500 ms
%                 else % correct
%                     curState = expState.End_Trial;
%                 end
%                 timeTag = GetSecs;
%                 expInfo.myResp(expInfo.curTrial,3) = correct;
%                 
%             case expState.Feedback_Wait
%                 
%                  if GetSecs - timeTag >= curState.duration
%                      v.flip;
%                      curState = expState.End_Trial;
%                      timeTag = GetSecs;
%                  end
                 
            case expState.End_Trial
                 % check if it is end of block or end of experiment or next
                 % trial

                 if GetSecs - timeTag >= curState.duration

                    if expInfo.curTrial >= exp.maxTrls
                        % end of experiment
                        infoText.thankyou='The experiment is finished! \nThank you very much!';
                        v.dispText(infoText.thankyou);
                        curState = expState.End_Exp; % finished
                        timeTag = GetSecs;
                    else % within experiment
                        if mod(expInfo.curTrial,blk_trials) == 0
                            % block break
                            curBlockStr = ['That was Block. No. ', num2str(expInfo.curTrial/blk_trials), ...
                                '. \n' num2str(num_block-expInfo.curTrial/blk_trials) ' blocks left. \n' ];
                            cond = exp.getCondition;
                            infoText.blkText= ['Please take a break! \n\n when you are ready, press any key to continue'];
                            v.dispText([curBlockStr infoText.blkText]);
                            curState=expState.Init_Block;        %added for trying, possibly should be deleted
                        else % normal next trial
                            curState = expState.Init_Trial;
                            timeTag = GetSecs;
                        end
                        expInfo.curTrial = expInfo.curTrial +1;
                    end
                    exp.setResp([stim.c_color stim.c_orient stim.c_target_pos,...
                        expInfo.myResp(expInfo.curTrial,1), expInfo.myResp(expInfo.curTrial,3),expInfo.myResp(expInfo.curTrial,2) ]); %store response: target position, kb.response, RT
%                     
                end
                    
                % store response and go on
                
                
            case expState.End_Exp
                if GetSecs - timeTag > curState.duration
                    timeTag = GetSecs;
                    expInfo.duration = (now-expInfo.StartTime)*60*24; % in minutes
                    stim.isFinished = 1;
                end
        end %end of switch 
    end  
            
        
        
        %%closing the experiment
        
        function Terminate(block)
            v.close;
            if ~isdir('popSearch_2x_data')
                mkdir('popSearch_2x_data')
            end
            save([datapath filesep 'popSearch_2x_data' filesep 'sub',num2str(block.InputPort(1).Data(1)),'_',datestr(now,'dd_mm_yyyy_HH_MM_SS')],'exp', 'expInfo');
        end
end             