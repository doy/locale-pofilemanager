package Locale::POFileManager;
use Moose;
use MooseX::Types::Path::Class qw(Dir);
use Scalar::Util qw(reftype weaken);

=head1 NAME

Locale::POFileManager - Helpers for keeping a set of related .po files in sync

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
the L<Locale::PO> parser library.

=cut

=head1 METHODS

=head2 new

=cut

=head2 base_dir

=cut

has base_dir => (
    is       => 'ro',
    isa      => Dir,
    required => 1,
    coerce   => 1,
);

=head2 files

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

=head2 canonical_language

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

=head2 stub_msgstr

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
            $weakself->canonical_language_file->entry_for($args{msgid})->msgstr
                if $weakself;
        $canonical_msgstr =~ s/^"|"$//g if defined($canonical_msgstr);
        return $msgstr->(
            %args,
            defined($canonical_msgstr) ? (canonical_msgstr => $canonical_msgstr) : (),
        );
    }
}

=head2 has_language

=cut

sub has_language {
    my $self = shift;
    my ($lang) = @_;

    for my $file ($self->files) {
        return 1 if $file->language eq $lang;
    }

    return;
}

=head2 add_language

=cut

sub add_language {
    my $self = shift;
    my ($lang) = @_;

    return if $self->has_language($lang);

    my $file = $self->base_dir->file("$lang.po");
    confess("Can't overwrite existing language file for $lang")
        if -e $file->stringify;

    my $msgstr = $self->stub_msgstr;
    my $pofile = Locale::POFileManager::File->new(
        file => $file,
        defined($msgstr) ? (stub_msgstr => $msgstr) : (),
    );
    $pofile->add_entry($self->canonical_language_file->entry_for(''));
    $pofile->save;

    $self->_add_file($pofile);
}

=head2 language_file

=cut

sub language_file {
    my $self = shift;
    my ($lang) = @_;

    return $self->_first_file(sub {
        $_->language eq $lang;
    });
}

=head2 canonical_language_file

=cut

sub canonical_language_file {
    my $self = shift;
    return $self->language_file($self->canonical_language);
}

=head2 find_missing

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

=head2 add_stubs

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

L<Locale::PO>

L<Locale::Maketext>

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

=head1 AUTHOR

  Jesse Luehrs <doy at tozt dot net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Jesse Luehrs.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
