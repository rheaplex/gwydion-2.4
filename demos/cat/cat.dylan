module: cat
rcs-header: $Header: /home/housel/work/rcs/gd/src/demos/cat/cat.dylan,v 1.6 1997/05/31 01:20:15 ram Exp $

// This demo demonstrates the streams library by duplicating the unix
// ``cat'' utility.
//

define method main (argv0 :: <byte-string>, #rest names)
  if (empty?(names))
    spew(*standard-input*);
  else
    for (name in names)
      let stream = if (name = "-")
		     make(<fd-stream>, fd: 0);
		   else
		     make(<file-stream>, locator: name);
		   end;
      spew(stream);
      close(stream);
    end;
  end if;
  force-output(*standard-output*);
end method;

define method spew (stream :: <stream>)
  let buf :: false-or(<buffer>) = get-input-buffer(stream);
  while (buf)
    write(*standard-output*, buf, start: buf.buffer-next, end: buf.buffer-end);
    buf.buffer-next := buf.buffer-end;
    buf := next-input-buffer(stream);
  end while;
  release-input-buffer(stream);
end;
