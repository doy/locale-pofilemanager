package Locale::POFileManager;
use Moose;
use MooseX::Types::Path::Class qw(Dir);

=head1 NAME

Locale::POFileManager -

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

has base_dir => (
    is       => 'ro',
    isa      => Dir,
    required => 1,
    coerce   => 1,
);

has files => (
    traits     => [qw(Array)],
    isa        => 'ArrayRef[Locale::POFileManager::File]',
    lazy       => 1,
    builder    => '_build_files',
    init_arg   => undef,
    handles    => {
        files      => 'elements',
        first_file => 'first',
        _add_file  => 'push',
    },
);

sub _build_files {
    my $self = shift;
    my $dir = $self->base_dir;

    require Locale::POFileManager::File;

    my @files;
    for my $file ($dir->children) {
        next unless $file->is_file;
        next unless $file->stringify =~ /\.po$/;
        push @files, Locale::POFileManager::File->new(file => $file);
    }

    return \@files;
}

has canonical_language => (
    is       => 'ro',
    isa      => 'Str',
    required => 1, # TODO: make this not required at some point?
);

sub BUILD {
    my $self = shift;

    confess("Canonical language file must exist")
        unless $self->has_language($self->canonical_language);
}

sub has_language {
    my $self = shift;
    my ($lang) = @_;

    for my $file ($self->files) {
        return 1 if $file->language eq $lang;
    }

    return;
}

sub add_language {
    my $self = shift;
    my ($lang) = @_;

    return if $self->has_language($lang);

    my $file = $self->base_dir->file("$lang.po");
    confess("Can't overwrite existing language file for $lang")
        if -e $file->stringify;

    my $pofile = Locale::POFileManager::File->new(file => $file);
    $pofile->save;

    $self->_add_file($pofile);
}

sub canonical_language_file {
    my $self = shift;
    my $lang = $self->canonical_language;

    return $self->first_file(sub {
        $_->file->language eq $lang;
    });
}

sub find_missing {
    my $self = shift;
    my $canon_file = $self->canonical_language_file;

    my %ret;
    for my $file ($self->files) {
        $ret{$file->language} = $file->find_missing_from($canon_file);
    }

    return %ret;
}

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

This software is copyright (c) 2009 by Jesse Luehrs.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
