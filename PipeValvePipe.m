%Prefer to use simscape/simulink model
%
%Represents flow restrictions connected in series
classdef PipeValvePipe < FlowRestriction
    properties
        pipe1;
        valve;
        pipe2;
    end
    methods
        %Varargin are classes they implement Flow Restriction that make up
        %this compound flow restriction. The order of varargin should be
        %from upstream to downstream
        function obj = PipeValvePipe(pipe1,valve,pipe2)
            obj.pipe1 = pipe1;
            obj.valve = valve;
            obj.pipe2 = pipe2;
        end
        
        function [T,P,X,vDownstream] = getDownstreamTemperaturePressureFromMassFlow(obj,mdot,fluidType,TUpstream,PUpstream,XUpstream,vUpstream)
            %TODO
            error('Currently unsupported');
        end
        
        function [T,mdot,X,vDownstream] = getDownstreamTemperatureMassFlowFromPressureChange(obj,dP,fluidType,TUpstream,PUpstream,XUpstream,vUpstream)
            if(dP == 0)
               T = TUpstream;
               mdot = 0;
               X = XUpstream;
               vDownstream = vUpstream;
               return;
            end
            PFinal = PUpstream + dP;
            
            P2 = PUpstream + (0.3*dP); %Initial guess for pressure downstream of pipe 1
            P3 = P2; %Initial guess for P3
%             tic;
            if(obj.valve.getFlowCoefficient() == 0)
               T = TUpstream;
               mdot = 0;
               X = XUpstream;
               vDownstream = 0;
               return;
            end
            %Solve with full calculations to get rough value for P2
            P2 = fzero(@(X) P2Err(X,NaN,NaN),P2);
            %Solve with "linearized" about P2 to find a more exact value
            P2About = P2;
            P2Err(P2,NaN,NaN);
            P3About = P3;
            P2 = fzero(@(X) P2Err(X,P2About,P3About),P2);
            P2 = real(abs(P2));
            if(P2 < PFinal)
                P2 = PFinal;
            end
            if(P2 > PUpstream)
                P2 = PUpstream;
            end
%             toc;
%             tic;
            P2Err(P2,P2About,P3About);
%             disp("Final P2: "+P2);
%             toc;
%             disp("P2: "+P2);
%             disp("P3: "+P3);
%             disp("P4: "+PFinal);
            
            function err = P2Err(P2,P2About,P3About)
                if(isnan(P2))
                    T = nan;
                    mdot = 0;
                    X = nan;
                    vDownstream = 0;
                    err = 10000;
                    return;
                end
                P2 = real(abs(P2));
                if(P2 < PFinal)
                   P2 = PFinal; 
                end
                if(P2 > PUpstream)
                   P2 = PUpstream; 
                end
                if isnan(P2About)
                    [T2,mdot,X2,vDownstream2] = obj.pipe1.getDownstreamTemperatureMassFlowFromPressureChange(P2-PUpstream,fluidType,TUpstream,PUpstream,XUpstream,vUpstream);
                else %"Linearize" about point for finding exact value to use
                    [T2,mdot,X2,vDownstream2] = obj.pipe1.getDownstreamTemperatureMassFlowFromDPAboutPt(P2About-PUpstream,P2-PUpstream,fluidType,TUpstream,PUpstream,XUpstream,vUpstream);
                end
                %                 disp("  X2: "+X2);
%                 disp("  T2: "+T2);
%                 disp("  P2: "+P2);
%                 disp("  mdot: "+mdot);
%                 drawnow;
                try
                    [T3,P3,X3,vDownstream3] = obj.valve.getDownstreamTemperaturePressureFromMassFlow(mdot,fluidType,T2,P2,X2,vDownstream2);
%                     disp("P2: "+P2+" mdot: "+mdot+" P3: "+P3);
                catch ME
%                      disp("Exception occured for mdot of: "+mdot +" ("+ME.identifier+"), P2: "+P2);
%                      drawnow;
                    if(strcmp(ME.identifier,'BallValve:DownstreamPTooLow') || strcmp(ME.identifier,'LinearValve:DownstreamPTooLow')) %P3 req for mass flow less than 88KPa
                        P3 = PFinal;
                        T = T2;
                        X = X2;
                        vDownstream = vDownstream2;
                        %mdot2 = 0; %Mass flow too high, P2 needs to be higher
                        %Find a smooth value for the error
                        dPValve = obj.valve.getPressureChangeForMassFlow(mdot,fluidType,T2,P2,X2);
                        P3 = P2 + dPValve;
%                         disp("P3 would have been: "+P3+" for mdot: "+mdot);
                        if(P3 < PFinal)
                           err = mdot; 
                        else
                            %Approx what mdot2 would be with this P3
                           [~,mdot2,~,~] = obj.pipe2.getDownstreamTemperatureMassFlowFromPressureChange(PFinal-P3,fluidType,SaturatedNitrous.getSaturationTemperature(P3),P3,X2,v2);
                            err = max(0.1,mdot-mdot2);
                        end
                        
%                          disp("Downstream P too low, P2: "+P2+" Err: "+err+" mdot: "+mdot);
                        return;
                    elseif(strcmp(ME.identifier,'BallValve:PNan') || strcmp(ME.identifier,'LinearValve:PNan')) %Valve is closed, downstream P can be any value
                        mdot2 = 0;
                        P3 = PFinal;
                        T = nan;
                        X = nan;
                        vDownstream = 0;
                        err = mdot-mdot2;
                        disp("PNan, err: "+err);
                        return;
                    else
                        disp("T2: "+T2);
                        disp("T1: "+TUpstream);
                        disp("P1: "+PUpstream);
                        disp("P2: "+P2);
                        disp("X2: "+X2);
                        drawnow;
                       rethrow(ME); 
                    end
                end
                if P3 < PFinal
                   mdot2 = 0; 
                   T = T3;
                   X = X3;
                   vDownstream = vDownstream3;
                else
                    if(imag(P3) ~= 0)
                        disp("P1: "+PUpstream);
                        disp("T1: "+TUpstream);
                        disp("X1: "+XUpstream);
                        disp("P2: "+P2);
                        disp("T2: "+T2);
                        disp("X2: "+X2);
                        disp("P3: "+P3);
                        disp("T3: "+T3);
                        disp("X3: "+X3);
                        disp("mdot: "+mdot);
                        drawnow;
                        error('P3 complex!');
                    end
                    try
                        if(isnan(P3About)) || true
                            [T,mdot2,X,vDownstream] = obj.pipe2.getDownstreamTemperatureMassFlowFromPressureChange(PFinal-P3,fluidType,T3,P3,X3,vDownstream3);
                        else
%                             disp("DOING P3 about pt!");
%                             disp("dP: "+(PFinal-P3));
%                             disp("P3 about: "+P3About+" P2 about: "+P2About);
                            [T,mdot2,X,vDownstream] = obj.pipe2.getDownstreamTemperatureMassFlowFromDPAboutPt(PFinal-P3About,PFinal-P3,fluidType,T3,P3About,X3,vDownstream3);
%                             disp("DONE P3 about pt!");
                        end
                    catch errorExc
                        disp("P1: "+PUpstream);
                        disp("T1: "+TUpstream);
                        disp("X1: "+XUpstream);
                        disp("P2: "+P2);
                        disp("T2: "+T2);
                        disp("X2: "+X2);
                        disp("P3: "+P3);
                        disp("T3: "+T3);
                        disp("X3: "+X3);
                        disp("mdot: "+mdot);
                        drawnow;
                        rethrow(errorExc);
                    end
                end
                err = (mdot-mdot2);
%                  disp("P2: "+P2+" P3: "+P3+" PFinal: "+PFinal+" mdot: "+mdot+" mdot2: "+mdot2+" err: "+err);
%                  drawnow;
            end
        end
        
        function mdot = getMassFlowForPressureChange(obj,dP,fluidType,TUpstream,PUpstream,XUpstream,vUpstream)
            [~,mdot,~,~] = obj.getDownstreamTemperatureMassFlowFromPressureChange(dP,fluidType,TUpstream,PUpstream,XUpstream,vUpstream);
        end
        
        function dP = getPressureChangeForMassFlow(obj,mdot,fluidType,TUpstream,PUpstream,XUpstream,vUpstream)
            [~,P,~,~] = obj.getDownstreamTemperaturePressureFromMassFlow(mdot,fluidType,TUpstream,PUpstream,XUpstream,vUpstream);
            dP = P-PUpstream;
        end
    end
end