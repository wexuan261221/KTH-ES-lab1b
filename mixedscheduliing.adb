pragma Priority_Specific_Dispatching(
                FIFO_Within_Priorities, 2, 30);
pragma Priority_Specific_Dispatching(
                Round_Robin_Within_Priorities, 1, 1);

with Ada.Text_IO;         use Ada.Text_IO;
with Ada.Float_Text_IO;
with Ada.Real_Time;       use Ada.Real_Time;

procedure mixedscheduling is
   package Duration_IO is new Ada.Text_IO.Fixed_IO(Duration);
   package Int_IO is new Ada.Text_IO.Integer_IO(Integer);

   Start : Time;
   Calibrator   : constant Integer := 3400;
   Warm_Up_Time : constant Integer := 100;

   ----------------------------
   -- Convert Time_Span to Float
   ----------------------------
   function To_Float(TS : Time_Span) return Float is
      SC   : Seconds_Count;
      Frac : Time_Span;
   begin
      Split(Time_Of(0, TS), SC, Frac);
      return Float(SC) + Time_Unit * Float(Frac / Time_Span_Unit);
   end To_Float;

   -------------------------
   -- Dummy workload
   -------------------------
   function F(N : Integer) return Integer is
      X : Integer := 0;
   begin
      for Index in 1..N loop
         for I in 1..500 loop
            X := X + I;
         end loop;
      end loop;
      return X;
   end F;

   -------------------------
   -- Periodic Task (Γ1)
   -------------------------
   task type T(Id: Integer; Prio: Integer; Phase: Integer;
               Period : Integer; Computation_Time : Integer;
               Relative_Deadline: Integer) is
      pragma Priority(Prio);
   end;

   task body T is
      Next, Release, Completed : Time;
      Response, WCRT           : Time_Span;
      Average_Response         : Float := 0.0;
      Absolute_Deadline        : Time;
      Iterations, Dummy        : Integer := 0;
   begin
      Release := Clock + Milliseconds(Phase);
      delay until Release;
      Next := Release;
      WCRT := Milliseconds(0);

      loop
         Next := Release + Milliseconds(Period);
         Absolute_Deadline := Release + Milliseconds(Relative_Deadline);

         -- Simulate computation
         for I in 1..Computation_Time loop
            Dummy := F(Calibrator);
         end loop;

         Completed := Clock;
         Response := Completed - Release;

         -- Compute average response
         Average_Response :=
           (Float(Iterations) * Average_Response + To_Float(Response))
           / Float(Iterations + 1);

         if Response > WCRT then
            WCRT := Response;
         end if;

         Iterations := Iterations + 1;

         Put("Task ");
         Int_IO.Put(Id, 1);
         Put(" Release:");
         Duration_IO.Put(To_Duration(Release - Start), 2, 3);
         Put(" Completion:");
         Duration_IO.Put(To_Duration(Completed - Start), 2, 3);
         Put(" Response:");
         Duration_IO.Put(To_Duration(Response), 1, 3);
         Put(" WCRT:");
         Ada.Float_Text_IO.Put(To_Float(WCRT), fore => 1, aft => 3, exp => 0);

         if Completed > Absolute_Deadline then
            Put(" ==> Task ");
            Int_IO.Put(Id, 1);
            Put(" violates Deadline!");
         end if;
         New_Line;

         Release := Next;
         delay until Release;
      end loop;
   end T;

   ----------------------------
   -- Background Task (Round-Robin)
   ----------------------------
   task type Background(Id: Integer) is
      pragma Priority(1);  -- low priority, RR scheduled
   end;

   task body Background is
      Dummy : Integer;
   begin
      loop
         -- simulate 100 ms work
         for I in 1..100 loop
            Dummy := F(Calibrator);
         end loop;
         Put_Line("Background Task" & Integer'Image(Id) & " executed");
      end loop;
   end Background;

   -------------------------
   -- Running Tasks
   -------------------------
   -- High priority RMS tasks (Γ1)
   Task_4 : T(4, 4, Warm_Up_Time, 300, 100, 300);
   Task_5 : T(5, 3, Warm_Up_Time, 400, 100, 400);
   Task_6 : T(6, 2, Warm_Up_Time, 600, 100, 600);

   -- Background tasks (Round-Robin)
   BG1 : Background(1);
   BG2 : Background(2);
   BG3 : Background(3);

begin
   Start := Clock;
   null;
end mixedscheduling;
