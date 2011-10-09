package Locale::POFileManager;
use Moose;
use MooseX::Types::Path::Class qw(Dir);
use Scalar::Util qw(reftype weaken);
# ABSTRACT: Helpers for keeping a set of related .po files in sync

=head1 SYNOPSIS

  use Locale::POFileManager;

  my $manager = Locale::POFileManager->new(
      base_dir           => '/path/to/app/i18n/po',
      canonical_language => 'en',
  );

  my %missing = $manager->find_missing;
  $manager->add_stubs;
  $manager->add_language('de');

=head1 DESCRIPTION

This module contains helpers for managing a set of gettext translation files,
including tools to keep the translation files in sync, adding new translation
files, and manipulating the translations contained in the files. It is based on
the L<Locale::Maketext::Lexicon> parser library.

=cut

=method new

Accepts a hash of arguments:

=over 4

=item base_dir

The directory that contains the .po files. Required.

=item canonical_language

The language for the file that contains the canonical set of msgids. Required.

=item stub_msgstr

The msgstr to insert when adding stubs to language files. This can be either a
literal string, or a coderef which accepts a hash containing the keys C<msgid>,
C<lang>, and C<canonical_msgstr> (the msgstr value from the
C<canonical_language>. Optional.

=back

=method base_dir

Returns a L<Path::Class::Dir> object corresponding to the C<base_dir> passed to
the constructor.

=cut

has base_dir => (
    is       => 'ro',
    isa      => Dir,
    required => 1,
    coerce   => 1,
);

=method files

Returns a list of L<Locale::POFileManager::File> objects corresponding to the
.po files that were found in the C<base_dir>.

=cut

has files => (
    traits     => [qw(Array)],
    isa        => 'ArrayRef[Locale::POFileManager::File]',
    lazy       => 1,
    builder    => '_build_files',
    init_arg   => undef,
    handles    => {
        files       => 'elements',
        _first_file => 'first',
        _add_file   => 'push',
    },
);

sub _build_files {
    my $self = shift;
    my $dir = $self->base_dir;

    require Locale::POFileManager::File;

    my @files;
    for my $file ($dir->children) {
        next if     $file->is_dir;
        next unless $file->stringify =~ /\.po$/;
        my $msgstr = $self->stub_msgstr;
        push @files, Locale::POFileManager::File->new(
            file  => $file,
            defined($msgstr) ? (stub_msgstr => $msgstr) : (),
        );
    }

    return \@files;
}

=method canonical_language

Returns the canonical language id passed to the constructor.

=cut

has canonical_language => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, # TODO: make this not required at some point?
);

has _stub_msgstr => (
    is       => 'ro',
    isa      => 'Str|CodeRef',
    init_arg => 'stub_msgstr',
);

sub BUILD {
    my $self = shift;

    confess("Canonical language file must exist")
        unless $self->has_language($self->canonical_language);
}

=method stub_msgstr

Returns the string passed to the constructor as C<stub_msgstr> if it was a
string, or a coderef wrapped to supply the C<canonical_msgstr> option if it was
a coderef.

=cut

sub stub_msgstr {
    my $self = shift;
    my $msgstr = $self->_stub_msgstr;
    return unless defined($msgstr);
    return $msgstr if !reftype($msgstr);
    my $weakself = $self;
    weaken($weakself);
    return sub {
        my %args = @_;
        my $canonical_msgstr;
        $canonical_msgstr =
            $weakself->canonical_language_file->msgstr($args{msgid})
                if $weakself;
        return $msgstr->(
            %args,
            defined($canonical_msgstr) ? (canonical_msgstr => $canonical_msgstr) : (),
        );
    }
}

=method has_language

Returns true if a language file exists for the given language in the
C<base_dir>, false otherwise.

=cut

sub has_language {
    my $self = shift;
    my ($lang) = @_;

    for my $file ($self->files) {
        return 1 if $file->language eq $lang;
    }

    return;
}

=method add_language

Creates a new language file for the language passed in as an argument. Creates
a header for that file copied over from the header in the C<canonical_language>
language file, and saves the newly created file in the C<base_dir>.

=cut

sub add_language {
    my $self = shift;
    my ($lang) = @_;

    return if $self->has_language($lang);

    my $file = $self->base_dir->file("$lang.po");
    confess("Can't overwrite existing language file for $lang")
        if -e $file->stringify;

    my $canon_pofile = $self->canonical_language_file;

    my $fh = $file->openw;
    $fh->binmode(':utf8');
    $fh->print(qq{msgid ""\n});
    $fh->print(qq{msgstr ""\n});
    for my $header_key ($canon_pofile->headers) {
        $fh->print(qq{"$header_key: }
                 . $canon_pofile->header($header_key)
                 . qq{\\n"\n});
    }
    $fh->print(qq{\n});
    $fh->close;

    my $msgstr = $self->stub_msgstr;
    my $pofile = Locale::POFileManager::File->new(
        file => $file,
        defined($msgstr) ? (stub_msgstr => $msgstr) : (),
    );


    $self->_add_file($pofile);
}

=method language_file

Returns the L<Locale::POFileManager::File> object corresponding to the given
language.

=cut

sub language_file {
    my $self = shift;
    my ($lang) = @_;

    return $self->_first_file(sub {
        $_->language eq $lang;
    });
}

=method canonical_language_file

Returns the L<Locale::POFileManager::File> object corresponding to the
C<canonical_language>.

=cut

sub canonical_language_file {
    my $self = shift;
    return $self->language_file($self->canonical_language);
}

=method find_missing

Searches through all of the files in the C<base_dir>, and returns a hash
mapping language names to an arrayref of msgids that were found in the
C<canonical_language> file but not in the file for that language.

=cut

sub find_missing {
    my $self = shift;
    my $canon_file = $self->canonical_language_file;

    my %ret;
    for my $file ($self->files) {
        $ret{$file->language} = [$file->find_missing_from($canon_file)];
    }

    return %ret;
}

=method add_stubs

Adds stub msgid (and possibly msgstr, if the C<stub_msgstr> option was given)
entries to each language file for each msgid found in the C<canonical_language>
file but not in the language file.

=cut

sub add_stubs {
    my $self = shift;
    my $canon_file = $self->canonical_language_file;

    for my $file ($self->files) {
        $file->add_stubs_from($canon_file);
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;

=head1 BUGS

No known bugs.

Please report any bugs through RT: email
C<bug-locale-pofilemanager at rt.cpan.org>, or browse to
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Locale-POFileManager>.

=head1 SEE ALSO

L<Locale::Maketext::Lexicon>

L<Locale::Maketext>

L<Locale::PO>

=head1 SUPPORT

You can find this documentation for this module with the perldoc command.

    perldoc Locale::POFileManager

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Locale-POFileManager>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Locale-POFileManager>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Locale-POFileManager>

=item * Search CPAN

L<http://search.cpan.org/dist/Locale-POFileManager>

=back

=begin Pod::Coverage

BUILD

=end Pod::Coverage

=cut

1;
