module: Dylan
author: William Lott (wlott@cs.cmu.edu)
rcs-header: $Header: /home/housel/work/rcs/gd/src/mindy/libraries/dylan/cond.dylan,v 1.9 1994/10/26 20:18:54 wlott Exp $

//======================================================================
//
// Copyright (c) 1994  Carnegie Mellon University
// All rights reserved.
// 
// Use and copying of this software and preparation of derivative
// works based on this software are permitted, including commercial
// use, provided that the following conditions are observed:
// 
// 1. This copyright notice must be retained in full on any copies
//    and on appropriate parts of any derivative works.
// 2. Documentation (paper or online) accompanying any system that
//    incorporates this software, or any part of it, must acknowledge
//    the contribution of the Gwydion Project at Carnegie Mellon
//    University.
// 
// This software is made available "as is".  Neither the authors nor
// Carnegie Mellon University make any warranty about the software,
// its performance, or its conformity to any specification.
// 
// Bug reports, questions, comments, and suggestions should be sent by
// E-mail to the Internet address "gwydion-bugs@cs.cmu.edu".
//
//======================================================================
//
// This file implements the condition system.
//


// Classes

define class <condition> (<object>)
end class <condition>;


define class <serious-condition> (<condition>)
end class <serious-condition>;


define class <error> (<serious-condition>)
end class <error>;


define class <simple-condition> (<condition>)
  slot condition-format-string,
    required-init-keyword: format-string:;
  slot condition-format-arguments,
    init-keyword: format-arguments:,
    init-value: #();
end class <simple-condition>;


define class <simple-error> (<error>, <simple-condition>)
end class <simple-error>;


define class <type-error> (<error>)
  slot type-error-value, init-keyword: value:;
  slot type-error-expected-type, init-keyword: type:;
end class <type-error>;


define class <warning> (<condition>)
end class <warning>;


define class <simple-warning> (<warning>, <simple-condition>)
end class <simple-warning>;


define class <restart> (<condition>)
end class <restart>;


define class <simple-restart> (<restart>, <simple-condition>)
end class <simple-restart>;


define class <abort> (<restart>)
  slot abort-description :: <byte-string>,
    init-keyword: description:,
    init-value: "<abort>";
end class <abort>;


// Condition reporting.

define generic report-condition (condition, stream);

define variable *format-function* =
  method (stream, string, #rest arguments)
    apply(format, string, arguments);
  end;

define variable *force-output-function* =
  method (stream)
    fflush();
  end;

define method report-condition (condition :: <condition>, stream)
  *format-function*(stream, "%=", condition);
end method report-condition;


define method report-condition (condition :: <simple-condition>, stream)
  apply(*format-function*, stream,
	condition.condition-format-string,
	condition.condition-format-arguments);
end method report-condition;


define method report-condition (condition :: <type-error>, stream)
  *format-function*(stream,
		    "%= is not of type %=",
		    condition.type-error-value,
		    condition.type-error-expected-type);
end method report-condition;


define method report-condition (condition :: <abort>, stream)
  *format-function*(stream, "%s", condition.abort-description);
end method report-condition;


// Condition signaling

define method signal (string :: <string>, #rest arguments)
  signal(make(<simple-warning>,
	      format-string: string,
	      format-arguments: arguments));
end method signal;


define method signal (cond :: <condition>, #rest noise)
  unless (empty?(noise))
    error("Can only supply format arguments when supplying a format string.");
  end;
  local
    method search (h)
      if (h)
	if (instance?(cond, h.handler-type))
	  let test = h.handler-test;
	  if (~test | test(cond))
	    let remaining = h.handler-next;
	    h.handler-function(cond, method () search(remaining) end);
	  else
	    search(h.handler-next);
	  end if;
	else
	  search(h.handler-next);
	end if;
      else
	default-handler(cond);
      end if;
    end method search;
  search(current-handler());
end method signal;


define method error (string :: <string>, #rest arguments)
  error(make(<simple-error>,
	     format-string: string,
	     format-arguments: arguments));
end method error;


define method error (cond :: <condition>, #rest noise)
  unless (empty?(noise))
    error("Can only supply format arguments when supplying a format string.");
  end;
  signal(cond);
  invoke-debugger(make(<simple-error>,
		       format-string:
			 "Attempt to return from a call to error"));
end method error;


define method cerror (restart-descr, cond-or-string, #rest arguments)
  block ()
    apply(error, cond-or-string, arguments);
  exception (<simple-restart>,
	     init-arguments: list(format-string: restart-descr,
				  format-arguments: arguments))
    #f;
  end block;
end method cerror;


define method type-error (value, type)
  error(make(<type-error>, value: value, type: type));
end method type-error;


define method check-type (value, type)
  if (instance?(value, type))
    value;
  else
    type-error(value, type);
  end if;
end method check-type;

define method abort ()
  error(make(<abort>));
end method abort;


define method default-handler (condition :: <condition>)
  #f;
end method default-handler;


define method default-handler (condition :: <serious-condition>)
  invoke-debugger(condition);
end method default-handler;


define method default-handler (condition :: <warning>)
  report-condition(condition);
  #f;
end method default-handler;


define method default-handler (restart :: <restart>)
  error("No restart handler for %=", restart);
end method default-handler;



// Breakpoints.

define class <breakpoint> (<simple-warning>)
end class <breakpoint>;


define method return-allowed? (cond :: <breakpoint>)
  #t;
end method return-allowed?;


define method return-query (cond :: <breakpoint>)
  #f;
end method return-query;


define method return-description (cond :: <breakpoint>)
  "Return #f";
end method return-description;


define method %break (string :: <string>, #rest arguments)
  %break(make(<breakpoint>,
	      format-string: string,
	      format-arguments: arguments));
end method %break;


define method %break (cond :: <condition>, #rest noise)
  unless (empty?(noise))
    error("Can only supply format arguments when supplying a format string.");
  end unless;
  block ()
    invoke-debugger(cond);
  exception (<simple-restart>,
	     init-arguments: list(format-string: "Continue from break"))
    #f;
  end block;
end method %break;


define method break (#rest arguments)
  if (empty?(arguments))
    %break("Break.");
  else
    apply(%break, arguments);
  end if;
end method break;



// Introspection.

define method do-handlers (function :: <function>)
  for (h = current-handler() then h.handler-next,
       while h)
    function(h.handler-type,
	     h.handler-test | method (x) #t end,
	     h.handler-function,
	     h.handler-init-args);
  end for;
end method do-handlers;


define method return-allowed? (cond :: <condition>)
  #f;
end method return-allowed?;


define generic return-description (cond);


// Interactive handling.

define method restart-query (restart :: <restart>)
  #f;
end method restart-query;


define generic return-query (condition);

