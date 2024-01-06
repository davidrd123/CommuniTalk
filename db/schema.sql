DROP TABLE if EXISTS comments;
DROP TABLE if EXISTS posts;
DROP TABLE if EXISTS users;

CREATE TABLE users (
  id serial PRIMARY KEY,
  username text NOT NULL,
  first_name text NOT NULL,
  last_name text,
  password text NOT NULL,
  created_at timestamp NOT NULL DEFAULT now()
);

CREATE TABLE posts (
  id serial PRIMARY KEY,
  title text NOT NULL,
  content text NOT NULL,
  user_id integer REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamp NOT NULL DEFAULT now()
);

CREATE TABLE comments (
  id serial PRIMARY KEY,
  content text NOT NULL,
  user_id integer REFERENCES users(id) ON DELETE CASCADE,
  post_id integer REFERENCES posts(id) ON DELETE CASCADE,
  created_at timestamp NOT NULL DEFAULT now()
);

INSERT INTO users (username, first_name, last_name, password) 
  VALUES ('admin', 'Admin', 'User', '$2a$12$fSSNe3VcV1KRQjpzEwhQZeowYUYC5kn8gvijj7sBv7KE0e2lLfL2i'),
         ('iago', 'Iago', NULL, '$2a$12$fSSNe3VcV1KRQjpzEwhQZeowYUYC5kn8gvijj7sBv7KE0e2lLfL2i'),
         ('othello', 'Othello', NULL, '$2a$12$fSSNe3VcV1KRQjpzEwhQZeowYUYC5kn8gvijj7sBv7KE0e2lLfL2i'),
         ('desdemona', 'Desdemona', NULL, '$2a$12$fSSNe3VcV1KRQjpzEwhQZeowYUYC5kn8gvijj7sBv7KE0e2lLfL2i'),
         ('prospero', 'Prospero', NULL, '$2a$12$fSSNe3VcV1KRQjpzEwhQZeowYUYC5kn8gvijj7sBv7KE0e2lLfL2i'),
         ('macbeth', 'Lord', 'Macbeth', '$2a$12$fSSNe3VcV1KRQjpzEwhQZeowYUYC5kn8gvijj7sBv7KE0e2lLfL2i'),
         ('lady_macbeth', 'Lady', 'Macbeth', '$2a$12$fSSNe3VcV1KRQjpzEwhQZeowYUYC5kn8gvijj7sBv7KE0e2lLfL2i'),
         ('beatrice', 'Beatrice', NULL, '$2a$12$fSSNe3VcV1KRQjpzEwhQZeowYUYC5kn8gvijj7sBv7KE0e2lLfL2i'),
         ('<script> javascript:alert(‘Executed!’); </script>', 'Script', 'Kiddie', '$2a$12$fSSNe3VcV1KRQjpzEwhQZeowYUYC5kn8gvijj7sBv7KE0e2lLfL2i');

         

INSERT INTO posts (title, content, user_id)
  VALUES ('Is a 4K monitor better in 30" or around 27"/28"', 
            'I know this isn''t a monitor board, but we''re all mini users here so I guess its appropriate. If I were to run a mini on a 4k 30" monitor, would that provide better readability and not require me to downscale?
             I just need help in choosing a monitor. Looking to bite the apple after thanksgiving
             [Original thread](https://forums.macrumors.com/threads/is-a-4k-monitor-better-in-30-or-around-27-28.2321033/)',
            1),
         ('I refuse to buy an Apple Silicon Mac with only 8 GB RAM!',
            'I''m aware that 8 GB RAM as of now fits most people''s needs. And that the Si/ARM SoC technology isn''t as RAM dependent as x86.\nBut macs are so expensive that I want them to last for regular use for a very long time. We know nothing of that now.
             [Original thread](https://forums.macrumors.com/threads/i-refuse-to-buy-an-apple-silicon-mac-with-only-8-gb-ram.2354473/)',
            3),
         ('Dell released their newest ultrasharp model ,U2723QE, U3223QE ultrasharp monitor',
            'Dell released their newest ultrasharp model, looks like this may be a cheap alternative and an enough good monitor for mac, 2000:1 contrast, not as good as apple display, but its not expensive
             [Original thread](https://forums.macrumors.com/threads/dell-released-their-newest-ultrasharp-model-u2723qe-u3223qe-ultrasharp-monitor.2333450/)',
            4),
         ('New theory of Gravitation',
            'Newton++',
            5),
         ('Newer theory of Gravitation',
            'Einstein++',
            6),
         ('What Is Quantum Field Theory and Why Is It Incomplete?',
            'Quantum field theory may be the most successful scientific theory of all time, but there''s reason to think it''s missing something. Steven Strogatz speaks with theoretical physicist David Tong about this enigmatic theory. [link to original comments](https://news.ycombinator.com/item?id=32425955)',
            7),
         ('Seventh Post',
            'etc',
            8),
         ('Eighth Post',
            'etc',
            8),
         ('Ninth Post',
            'etc',
            8),
         ('Tenth Post',
            'etc',
            9),
         ('Eleventh Post',
            'etc',
            2),
         ('Twelfth Post',
            'etc',
            3),
         ('Thirteenth Post',
            'etc',
            1),
         ('Fourteenth Post',
            'etc',
            1),
         ('Fifteenth Post',
            'etc',
            1),
         ('Sixteenth Post',
            'etc',
            1),
         ('Seventeenth Post',
            'etc',
            1),
          ('<script> javascript:alert(‘Executed!’); </script>',
            '<script> javascript:alert(‘Executed!’); </script>',
            9);
         
         

INSERT INTO comments (content, user_id, post_id) 
  VALUES ('How''s your eyesight?
          I''m thinking that "true 4k" (not scaled at all) would yield menus and text (when displayed at normal font sizes) too small and very difficult to read on any display under, say, 43"',
            1, 1),
         ('A 32" 4K is ≈138 ppi. I have good vision and can just about cope with that. However, there''s a case for the HiDPI modes, i.e. downscaling, nonetheless - the fact that font rendering is awful on macOS in non-HiDPI (i.e. native 4K without downscaling) modes.',
            4, 1),
         ('Yes, running with the native resolution of 3840x2160 is WAY too small on a 27" monitor, and is still too small on the 32" (usable, but unless you are right on top of the display, it''s still too small).
          HiDPI modes are the answer. On a 27" I''d recommend the "looks like 2560x1440" mode, as this gives you the same screen real estate and look (but sharper) as a standard 27" QHD monitor.',
            5, 1),
         ('I would say 27" is the absolute maximum for what I would consider somewhat acceptable for 4K, and if possible, I would never go below ~220 ppi. Text looks crisp on the iMac, but on the 4K it is a little jagged, and I feel it in my head and eyes if I try to spend more than a few minutes reading on it.
          I would never ever consider 30" at 4K unless I was going to set it scaled to "look like" a much smaller resolution and look at it from across the room.',
            6, 1),
         ('You''ll find good answers to this question by going to [this resource](https://bjango.com/articles/macexternaldisplays/) hosted by developer Bjango.
          In short, you''ll want as high a PPI as possible, and @prospero is correct: 27" should be the max for a 4K display and still look crisp. Personally, I gave up on nailing the best 4K experience and just ponied up for an LG 5K UltraFine. Yes, it''s in that plastic housing and no where near as sexy as an Apple-designed product. Yes, it''s got poor support. Yes, the built-in speakers suck. But wow what a display!',
            7, 1),
         ('Agreed. [Here](https://forums.macrumors.com/threads/is-there-any-external-monitor-comparable-to-the-new-24inch-m1-imac.2312210/post-30314701) is a list of (mostly discontinued) ≈220 ppi displays. I have a Dell UP2715K (discontinued) and it''s freaking awesome.',
            4, 1),
         ('Based on these comments I am wondering why one should ever get a 4K 27" monitor. Perhaps for photography/video?',
            8, 1),
         ('How far from the screen you sit is also a factor in this.
          It is a triangle of trade-offs between screen res, screen size, and viewing distance.',
            3, 1),
         ('<b>hello</b>',
            4, 5),
         ('<b>hello</b>',
            5, 5),
         ('<script> javascript:alert(‘Executed!’); </script>',
            9, 5),
         ('Probably the highest point in my physics "career" was when my advisor recommended [Quantum Field Theory for the Gifted Amateur](https://www.goodreads.com/book/show/18781406-quantum-field-theory-for-the-gifted-amateur) to me. It was after I had basically decided to abandon hope at academia and become an engineer, but I was just barely past the threshold of being able to understand the contents. I worked through the book solo and really greatly enjoyed it; highly visual and well paced. I''d recommend it to any undergrad+ who has made it past bra-kets and wants to see how far the rabbit hole goes.',
            3, 6),
         ('Another great book at that level is Student friendly Quantum Field Theory by Klauber. Especially if you struggle with the incomplete math treatments in standard books like Peskin & Schroeder, where the first chapter basically assumes you already know all the weird complex contour integrals that you usually only encounter in QFT. If Klauber says "from this easily follows ..." then you can expect to understand it even if you''re not yet an expert. Ofc that comes with less depth in total, but there''s no point in talking about renormalization if you haven''t understood field quantization.',
            4, 6),
         ('My undergrad is in Computer Science and Engineering, but I would love to read and understand this book. Any recommendations for what to know beforehand? Some prerequisite books or subjects, maybe?',
            5, 6),
         ('It''s been a while now since I''ve picked it up, but I think the main content it assumes your comfortable with is on the order of a semester of Quantum Mechanics. Otherwise, it definitely uses quite a few tricks in calculus (e.g. integrating probability amplitudes, variational calculus, and likely some higher dimensional stuff). The later chapters probably get even more exotic, but the book prepares the reader pretty well I think.',
            6, 6),
         ('The Feynman lectures have a reputation for being very hit and miss. People who "get it" will find them really interesting and useful. But if you don''t, then it might just confuse you.
          I know a condensed matter postdoc who told me he felt ready to tackle the Feynman lectures only after he had completed his phd....',
            7, 6),
         ('They''re a great companion book, but you really need a book that guides you through derivations and computations. Some techniques are non-obvious like choosing coordinate systems to make integrals easier, clever contours when applying residue theorem, change of variables using orthogonal matrices to diagonalize symmetric matrices, etc.',
            6, 6),
         ('Something that covers calculus of variations, Euler-Legrange equation, etc. I first covered this in Classical Mechanics but don''t remember the textbook. The Feynman Lectures of Physics [2] probably covers it, but I don''t know for certain.
          Indeed it does:

          [https://www.feynmanlectures.caltech.edu/II_19.html](https://www.feynmanlectures.caltech.edu/II_19.html)
          
          The original lecture recording is also available:
          
          [https://www.feynmanlectures.caltech.edu/flptapes.html](https://www.feynmanlectures.caltech.edu/flptapes.html)',
            8, 6);
         
         