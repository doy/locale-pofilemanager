package Locale::POFileManager::File;
use Moose;

use MooseX::Types::Path::Class qw(File);
use List::MoreUtils qw(any);
use Locale::PO;
use Scalar::Util qw(reftype);

has file => (
    is       => 'ro',
    isa      => File,
    coerce   => 1,
    required => 1,
);

has stub_msgstr => (
    is       => 'ro',
    isa      => 'Str|CodeRef',
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
        msgids    => [ map => sub { my $m = $_->msgid; $m =~ s/^"|"$//g; $m } ],
    },
);

sub _build_entries {
    my $self = shift;
    my $filename = $self->file->stringify;

    return (-r $filename) ? Locale::PO->load_file_asarray($filename) : [];
}

sub entry_for {
    my $self = shift;
    my ($msgid) = @_;
    return grep { $_->msgid eq $msgid } $self->entries;
}

sub save {
    my $self = shift;

    Locale::PO->save_file_fromarray($self->file->stringify, [$self->entries]);
}

sub language {
    my $self = shift;
    my $language = $self->file->basename;
    $language =~ s{(.*)\.po$}{$1};
    return $language;
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

    for my $missing ($self->find_missing_from($other)) {
        my $msgstr = $self->stub_msgstr;
        if (reftype($msgstr) && reftype($msgstr) eq 'CODE') {
            $msgstr = $msgstr->(lang => $self->language, msgid => $missing);
        }
        my $entry = Locale::PO->new(
            -msgid => $missing,
            defined($msgstr) ? (-msgstr => $msgstr) : (),
        );
        $self->add_entry($entry);
    }

    $self->save;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
