package Locale::POFileManager::File;
use Moose;

use MooseX::Types::Path::Class qw(File);
use List::MoreUtils qw(any);
use List::Util qw(first);
use Locale::PO;
use Scalar::Util qw(reftype);

=head1 NAME

Locale::POFileManager::File - A single .po file

=head1 SYNOPSIS

  use Locale::POFileManager;

  my $manager = Locale::POFileManager->new(
      base_dir           => '/path/to/app/i18n/po',
      canonical_language => 'en',
  );
  my $file = $manager->language_file('de');

  $file->add_entry(
      msgid  => 'Hello',
      msgstr => 'Guten Tag'
  );
  my @entries = $file->entries;
  my $entry = $file->entry_for('Hello');
  $file->save;

=head1 DESCRIPTION

This module represents a single translation file, providing methods for
manipulating the translation entries in it.

=cut

=head1 METHODS

=head2 new

Accepts a hash of arguments:

=over 4

=item file

The name of the file this represents. Required.

=item stub_msgstr

The msgstr to insert when adding stubs to language files. This can be either a
literal string, or a coderef which accepts a hash containing the keys C<msgid>
and C<lang>. Optional.

=cut

=head2 file

Returns a L<Path::Class::File> object corresponding to the C<file> passed to
the constructor.

=cut

has file => (
    is       => 'ro',
    isa      => File,
    coerce   => 1,
    required => 1,
);

=head2 stub_msgstr

Returns the C<stub_msgstr> passed to the constructor.

=cut

has stub_msgstr => (
    is       => 'ro',
    isa      => 'Str|CodeRef',
);

=head2 entries

Returns a list of L<Locale::PO> objects corresponding to translation entries in
the file.

=cut

=head2 add_entry

Adds a new translation entry to the file. This can be provided either as a
L<Locale::PO> object directly, or as a hash of options to pass to the
L<Locale::PO> constructor (except without the leading dashes).

=cut

=head2 msgids

Returns a list of msgids found in the file.

=cut

has entries => (
    traits   => [qw(Array)],
    isa      => 'ArrayRef[Locale::PO]',
    lazy     => 1,
    builder  => '_build_entries',
    init_arg => undef,
    handles  => {
        entries    => 'elements',
        _add_entry => 'push',
        msgids     =>
            [ map => sub { my $m = $_->msgid; $m =~ s/^"|"$//g; $m } ],
    },
);

sub _build_entries {
    my $self = shift;
    my $filename = $self->file->stringify;

    return (-r $filename) ? Locale::PO->load_file_asarray($filename) : [];
}

sub add_entry {
    my $self = shift;
    if (@_ == 1) {
        $self->_add_entry($_[0]);
    }
    else {
        my %args = @_;
        $args{"-$_"} = delete $args{$_} for keys %args;
        $self->_add_entry(Locale::PO->new(%args));
    }
}

=head2 entry_for

Returns the L<Locale::PO> object corresponding to the given msgid.

=cut

sub entry_for {
    my $self = shift;
    my ($msgid) = @_;
    return first { $_->msgid eq '"' . $msgid . '"' } $self->entries;
}

=head2 save

Writes the current contents of the file back out to disk.

=cut

sub save {
    my $self = shift;

    Locale::PO->save_file_fromarray($self->file->stringify, [$self->entries]);
}

=head2 language

Returns the language that this file corresponds to.

=cut

sub language {
    my $self = shift;
    my $language = $self->file->basename;
    $language =~ s{(.*)\.po$}{$1};
    return $language;
}

=head2 find_missing_from

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

=head2 add_stubs_from

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

    $self->save;
}

__PACKAGE__->meta->make_immutable;
no Moose;

=head1 AUTHOR

  Jesse Luehrs <doy at tozt dot net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Jesse Luehrs.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
