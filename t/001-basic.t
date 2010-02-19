#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp;
use File::Copy;
use Path::Class;

use Locale::POFileManager;

{
    my $manager = Locale::POFileManager->new(
        base_dir           => 't/data/001',
        canonical_language => 'en',
    );

    is_deeply({$manager->find_missing},
              {ru => [qw(bar baz)], hi => [qw(bar)], en => [], de => []},
              "got the correct missing messages");
}

{
    my $dir = File::Temp->newdir;
    my $from_dir = dir('t/data/001');
    for my $file ($from_dir->children) {
        copy($file->stringify, $dir->dirname);
    }
    my $manager = Locale::POFileManager->new(
        base_dir           => $dir->dirname,
        canonical_language => 'en',
    );
    $manager->add_stubs;
    is_deeply({$manager->find_missing},
              {ru => [], hi => [], en => [], de => []},
              "got the correct missing messages");

    my $header = <<'HEADER';
msgid ""
msgstr ""
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=utf-8\n"
"Content-Transfer-Encoding: 8bit\n"

HEADER

    my %langs = (
        en => qq{msgid "foo"\nmsgstr "foo"\n\n}
            . qq{msgid "bar"\nmsgstr "bar"\n\n}
            . qq{msgid "baz"\nmsgstr "baz"\n\n},
        ru => qq{msgid "foo"\nmsgstr "foo"\n\n}
            . qq{msgid "bar"\n\n}
            . qq{msgid "baz"\n\n},
        hi => qq{msgid "foo"\nmsgstr "foo"\n\n}
            . qq{msgid "baz"\nmsgstr "baz"\n\n}
            . qq{msgid "bar"\n\n},
        de => qq{msgid "foo"\nmsgstr "foo"\n\n}
            . qq{msgid "bar"\nmsgstr "bar"\n\n}
            . qq{msgid "baz"\nmsgstr "baz"\n\n},
    );

    for my $file ($manager->files) {
        is($file->file->slurp, $header . $langs{$file->language},
           "got the right stubs");
    }
}

done_testing;
