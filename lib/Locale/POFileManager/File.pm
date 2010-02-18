package Locale::POFileManager::File;
use Moose;

use MooseX::Types::Path::Class qw(File);
use List::MoreUtils qw(any);
use Locale::PO;

has file => (
    is       => 'ro',
    isa      => File,
    coerce   => 1,
    required => 1,
);

has entries => (
    traits   => [qw(Array)],
    isa      => 'ArrayRef[Locale::PO]',
    lazy     => 1,
    builder  => '_build_entries',
    init_arg => undef,
    handles  => {
        entries   => 'elements',
        add_entry => 'push',
        msgids    => [ map => sub { $_->msgid } ],
    },
);

sub _build_entries {
    my $self = shift;
    my $filename = $self->file->stringify;

    return (-r $filename) ? Locale::PO->load_file_asarray($filename) : [];
}

sub save {
    my $self = shift;

    Locale::PO->save_file_fromarray($self->file->stringify, [$self->entries]);
}

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

sub add_stubs_from {
    my $self = shift;
    my ($other) = @_;

    $self->add_entry($_) for map { Locale::PO->new(-msgid => $_) }
                                 $self->find_missing_from($other);
    $self->save;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
