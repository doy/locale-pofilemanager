#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp;
use File::Copy;
use Path::Class;

use Locale::POFileManager;

{
    my $dir = File::Temp->newdir;
    my $from_dir = dir('t/data/002');
    my $tmpdir = dir($dir->dirname);
    for my $file ($from_dir->children) {
        copy($file->stringify, $dir->dirname);
    }
    my $header = $tmpdir->file('en.po')->slurp;
    $header =~ s/\n\n.*/\n\n/s;

    my $manager = Locale::POFileManager->new(
        base_dir           => $dir->dirname,
        canonical_language => 'en',
    );
    is_deeply([sort map { $_->basename } $tmpdir->children],
              [qw(en.po)],
              "correct initial directory contents");

    $manager->add_language('ru');
    $manager->add_language('hi');

    is_deeply([sort map { $_->basename } $tmpdir->children],
              [qw(en.po hi.po ru.po)],
              "correct directory contents after creation");

    for my $lang (qw(ru hi)) {
        is($tmpdir->file("$lang.po")->slurp, $header,
           "got the right header in $lang.po");
    }

    $manager->language_file('ru')->add_entry(
        msgid  => 'baz',
        msgstr => 'Zab',
    );
    is_deeply([sort $manager->language_file('ru')->msgids],
              ['', qw(baz)],
              "created new entry successfully");
    is($manager->language_file('ru')->entry_for('baz')->msgstr, '"Zab"',
       "correct entry created");

    is_deeply([sort $manager->language_file('hi')->msgids],
              [''],
              "other language file untouched");

    $manager->add_stubs;

    for my $lang (qw(ru hi)) {
        is_deeply([sort $manager->language_file($lang)->msgids],
                  ['', qw(bar baz foo)],
                  "stubs for $lang created properly");
    }

    my %langs = (
        en => qq{msgid "foo"\nmsgstr "foo"\n\n}
            . qq{msgid "bar"\nmsgstr "bar"\n\n}
            . qq{msgid "baz"\nmsgstr "baz"\n\n},
        hi => qq{msgid "foo"\n\n}
            . qq{msgid "bar"\n\n}
            . qq{msgid "baz"\n\n},
        ru => qq{msgid "baz"\nmsgstr "Zab"\n\n}
            . qq{msgid "foo"\n\n}
            . qq{msgid "bar"\n\n},
    );

    for my $lang (keys %langs) {
        is($manager->language_file($lang)->file->slurp, $header . $langs{$lang},
           "files created properly");
    }
}

done_testing;
