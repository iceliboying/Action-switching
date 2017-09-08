classdef expState
    properties
       duration = 0;
    end 
    
   methods
      function c = expState(d)
         c.duration = d;
      end
   end
    enumeration
        
        Init_Exp (0) 
        Init_Exp_Wait (inf)
        New_Block_Wait (inf)
        Block_Wait(inf)
        Init_Block (10)
        Init_Trial (inf)
        Fixation (0.3) 
        Cue (0)
        Cue_Wait(0.7)
        Target (0)
        Response (inf) 
        Feedback (0) 
        Feedback_Wait (0.5) 
        End_Trial (1.2)
        End_Block (1) 
        End_Exp (2)
    end
end
