package Locale::POFileManager::File;
use Moose 0.90;
# ABSTRACT: A single .po file

use MooseX::Types::Path::Class qw(File);
use List::MoreUtils qw(any);
use List::Util qw(first);
use Locale::Maketext::Lexicon::Gettext;
use Scalar::Util qw(reftype);

require Locale::Maketext::Lexicon;
Locale::Maketext::Lexicon::set_option(decode => 1);
Locale::Maketext::Lexicon::set_option(allow_empty => 1);

=head1 SYNOPSIS

  use Locale::POFileManager;

  my $manager = Locale::POFileManager->new(
      base_dir           => '/path/to/app/i18n/po',
      canonical_language => 'en',
  );
  my $file = $manager->language_file('de');
  my $lang = $file->language; # 'de'

  $file->add_entry(
      msgid  => 'Hello',
      msgstr => 'Guten Tag'
  );

  my $translation = $file->msgstr('Hello'); # 'Guten Tag'

=head1 DESCRIPTION

This module represents a single translation file, providing methods for
manipulating the translation entries in it.

=cut

=method new

Accepts a hash of arguments:

=over 4

=item file

The name of the file this represents. Required, and must exist.

=item stub_msgstr

The msgstr to insert when adding stubs to language files. This can be either a
literal string, or a coderef which accepts a hash containing the keys C<msgid>
and C<lang>. Optional.

=back

=cut

=method file

Returns a L<Path::Class::File> object corresponding to the C<file> passed to
the constructor.

=cut

has file => (
    is       => 'ro',
    isa      => File,
    coerce   => 1,
    required => 1,
);

=method stub_msgstr

Returns the C<stub_msgstr> passed to the constructor.

=cut

has stub_msgstr => (
    is       => 'ro',
    isa      => 'Str|CodeRef',
);

=method msgids

Returns a list of msgids found in the file.

=method has_msgid

Returns true if the given msgid is found in the file, and false otherwise.

=method msgstr

Returns the msgstr that corresponds with the given msgid.

=cut

has lexicon => (
    traits  => [qw(Hash)],
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return Locale::Maketext::Lexicon::Gettext->parse($self->file->slurp);
    },
    handles => {
        msgids             => 'keys',
        has_msgid          => 'exists',
        _remove_msgid      => 'delete',
        msgstr             => 'get',
        _add_lexicon_entry => 'set',
    },
);

=method headers

Returns the list of header entries.

=method header

Returns the value of the given header entry.

=cut

has headers => (
    traits  => [qw(Hash)],
    isa     => 'HashRef',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $ret = {};
        $ret->{$_} = $self->_remove_msgid("__$_")
            for map { s/^__//; $_ } grep { /^__/ } $self->msgids;
        return $ret;
    },
    handles => {
        headers => 'keys',
        header  => 'get',
    },
);

sub BUILD {
    my $self = shift;

    my $filename = $self->file->stringify;
    confess "Can't read file " . $filename
        unless -r $filename;

    # strip the headers out of the lexicon hash
    $self->headers;
}

=method add_entry

Adds an entry to the translation file. Arguments are a hash, with valid keys
being C<msgid> and C<msgstr>.

=cut

sub add_entry {
    my $self = shift;
    my %args = @_;
    my ($msgid, $msgstr) = @args{qw(msgid msgstr)};

    return if $self->has_msgid($msgid);

    my $needs_newline = ($self->file->slurp !~ /\n\n$/);
    my $fh = $self->file->open('>>');
    $fh->binmode(':utf8');
    $fh->print(qq{\n}) if $needs_newline;

    $fh->print(qq{msgid "$msgid"\n});
    $fh->print(qq{msgstr "$msgstr"\n}) if defined $msgstr;
    $fh->print(qq{\n});

    $self->_add_lexicon_entry($msgid => $msgstr);
}

=method language

Returns the language that this file corresponds to.

=cut

sub language {
    my $self = shift;
    my $language = $self->file->basename;
    $language =~ s{(.*)\.po$}{$1};
    return $language;
}

=method find_missing_from

Takes another translation file (either as a filename or as a
L<Locale::POFileManager::File> object), and returns a list of msgids that the
given file contains that this file doesn't.

=cut

sub find_missing_from {
    my $self = shift;
    my ($other) = @_;
    $other = blessed($self)->new(file => $other) unless blessed($other);

    my @ret;
    my @msgids = $self->msgids;
    for my $msgid ($other->msgids) {
        push @ret, $msgid unless any { $msgid eq $_ } @msgids;
    }

    return @ret;
}

=method add_stubs_from

Takes another translation file (either as a filename or as a
L<Locale::POFileManager::File> object), and adds stubs for each msgid that the
given file contains that this file doesn't.

=cut

sub add_stubs_from {
    my $self = shift;
    my ($other) = @_;

    for my $missing ($self->find_missing_from($other)) {
        my $msgstr = $self->stub_msgstr;
        if (reftype($msgstr) && reftype($msgstr) eq 'CODE') {
            $msgstr = $msgstr->(lang => $self->language, msgid => $missing);
        }
        $self->add_entry(
            msgid => $missing,
            defined($msgstr) ? (msgstr => $msgstr) : (),
        );
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;

=pod

=begin Pod::Coverage

BUILD

=end Pod::Coverage

=cut

1;
