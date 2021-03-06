package BioX::Workflow::Command::run::Rules::Rules;

use MooseX::App::Role;
use namespace::autoclean;

use Storable qw(dclone);
#use Data::Merger qw(merger);
use Data::Dumper;
use File::Path qw(make_path remove_tree);
use Try::Tiny;
use Path::Tiny;
use MCE::Map;
use Algorithm::Loops qw(NestedLoops);

use BioSAILs::Utils::Traits qw(ArrayRefOfStrs);
use MCE::Shared;
use MCE::Shared::Cache;

use BioX::Workflow::Command::run::Rules::Exceptions::KeyDeclaration;
use BioX::Workflow::Command::run::Rules::Exceptions::OneRuleName;

with 'BioX::Workflow::Command::run::Rules::Directives::Inspect';

tie my %stash, 'MCE::Shared', { module => 'MCE::Shared::Cache' };

=head1 Name

BioX::Workflow::Command::run::Rules::Rules

=head2 Description

Role for Rules

=cut

=head2 Command Line Options

=cut

option 'select_rules' => (
    traits        => [ 'Array' ],
    is            => 'rw',
    required      => 0,
    isa           => ArrayRefOfStrs,
    documentation => 'Select rules to process',
    default       => sub {[]},
    cmd_split     => qr/,/,
    handles       => {
        all_select_rules  => 'elements',
        has_select_rules  => 'count',
        join_select_rules => 'join',
    },
    cmd_aliases   => [ 'sr' ],
);

option 'select_after' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 0,
    predicate     => 'has_select_after',
    clearer       => 'clear_select_after',
    documentation => 'Select rules after and including a particular rule.',
    cmd_aliases   => [ 'sa' ],
);

option 'select_before' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 0,
    predicate     => 'has_select_before',
    clearer       => 'clear_select_before',
    documentation => 'Select rules before and including a particular rule.',
    cmd_aliases   => [ 'sb' ],
);

option 'select_between' => (
    traits        => [ 'Array' ],
    is            => 'rw',
    isa           => ArrayRefOfStrs,
    documentation => 'select rules to process',
    cmd_split     => qr/,/,
    required      => 0,
    default       => sub {[]},
    documentation => 'Select sets of rules. Ex: rule1-rule2,rule4-rule5',
    cmd_aliases   => [ 'sbtwn' ],
    handles       => {
        all_select_between  => 'elements',
        has_select_between  => 'count',
        join_select_between => 'join',
    },
);

option 'omit_rules' => (
    traits        => [ 'Array' ],
    is            => 'rw',
    required      => 0,
    isa           => ArrayRefOfStrs,
    documentation => 'Omit rules to process',
    default       => sub {[]},
    cmd_split     => qr/,/,
    handles       => {
        all_omit_rules  => 'elements',
        has_omit_rules  => 'count',
        join_omit_rules => 'join',
    },
    cmd_aliases   => [ 'or' ],
);

option 'omit_after' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 0,
    predicate     => 'has_omit_after',
    clearer       => 'clear_omit_after',
    documentation => 'Omit rules after and including a particular rule.',
    cmd_aliases   => [ 'oa' ],
);

option 'omit_before' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 0,
    predicate     => 'has_omit_before',
    clearer       => 'clear_omit_before',
    documentation => 'Omit rules before and including a particular rule.',
    cmd_aliases   => [ 'ob' ],
);

option 'omit_between' => (
    traits        => [ 'Array' ],
    is            => 'rw',
    isa           => ArrayRefOfStrs,
    documentation => 'omit rules to process',
    cmd_split     => qr/,/,
    required      => 0,
    default       => sub {[]},
    documentation => 'Omit sets of rules. Ex: rule1-rule2,rule4-rule5',
    cmd_aliases   => [ 'obtwn' ],
    handles       => {
        all_omit_between  => 'elements',
        has_omit_between  => 'count',
        join_omit_between => 'join',
    },
);

option 'select_match' => (
    traits        => [ 'Array' ],
    is            => 'rw',
    required      => 0,
    isa           => ArrayRefOfStrs,
    documentation => 'Match rules to select',
    default       => sub {[]},
    cmd_split     => qr/,/,
    handles       => {
        all_select_match  => 'elements',
        has_select_match  => 'count',
        join_select_match => 'join',
    },
    cmd_aliases   => [ 'sm' ],
);

option 'omit_match' => (
    traits        => [ 'Array' ],
    is            => 'rw',
    required      => 0,
    isa           => ArrayRefOfStrs,
    documentation => 'Match rules to omit',
    default       => sub {[]},
    cmd_split     => qr/,/,
    handles       => {
        all_omit_match  => 'elements',
        has_omit_match  => 'count',
        join_omit_match => 'join',
    },
    cmd_aliases   => [ 'om' ],
);

# TODO Change this to rules?
has 'rule_keys' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub {return []},
);

has 'local_rule_keys' => (
    traits  => [ 'Array' ],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub {return []},
    handles => {
        all_local_rule_keys => 'elements',
        has_local_rule_keys => 'count',
    },
);

has 'global_keys' => (
    traits  => [ 'Array' ],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub {return []},
    handles => {
        all_global_keys         => 'elements',
        has_global_keys         => 'count',
        first_index_global_keys => 'first_index',
    },
);

has [ 'select_effect', 'omit_effect' ] => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has 'dummy_sample' => (
    is      => 'rw',
    isa     => 'Str',
    default => '__DUMMYSAMPLE123456789__'
);

has 'dummy_iterable' => (
    is      => 'rw',
    isa     => 'Str',
    default => '__DUMMYITER123456789__'
);

#This should be in its own role
sub iterate_rules {
    my $self = shift;

    $self->set_rule_names;
    my $rules = $self->workflow_data->{rules};

    $self->filter_rule_keys;

    foreach my $rule (@$rules) {
        $self->local_rule($rule);
        my $except = $self->process_rule;
        next if $except;
        $self->p_rule_name($self->rule_name);
        $self->p_local_attr(dclone($self->local_attr));
    }
}

=head3 filter_rule_keys

First option is to use --use_timestamps
The user can also override the timestamps with --select_* --omit_*

Use the --select_rules and --omit_rules options to choose rules.

By default all rules are selected

=cut

sub filter_rule_keys {
    my $self = shift;

    $self->select_rule_keys(dclone($self->rule_names));

    $self->set_rule_keys('select');
    $self->set_rule_keys('omit');

    $self->app_log->info('Selected rules:' . "\t"
        . join(', ', @{$self->select_rule_keys})
        . "\n");
}

=head3 set_rule_names

Iterate over the rule names and add them to our array

=cut

sub set_rule_names {
    my $self = shift;
    my $rules = $self->workflow_data->{rules};

    my @rule_names = map {my ($key) = keys %{$_};
        $key} @{$rules};
    @rule_names = map {my $t = $_;
        $t =~ s/^\s+|\s+$//g;
        $t} @rule_names;
    $self->rule_names(\@rule_names);
    $self->app_log->info('Found rules:' . "\t" . join(', ', @rule_names));
}

#TODO This is confusing change names

=head3 set_rule_keys

If we have any select_* or select_match, get those rules before we start processing

=cut

sub set_rule_keys {
    my $self = shift;
    my $cond = shift || 'select';

    my @rules = ();
    my $rule_exists = 1;
    my @rule_name_exists = ();

    my $effect = $cond . '_effect';

    my ($has_rules, $has_bf, $has_af, $has_btw, $has_match) =
        map {'has_' . $cond . '_' . $_}
            ('rules', 'before', 'after', 'between', 'match');

    my ($bf, $af) = ($cond . '_before', $cond . '_after');

    my ($btw, $all_rules, $all_matches) =
        map {'all_' . $cond . '_' . $_} ('between', 'rules', 'match');

    my ($rule_keys) = ($cond . '_rule_keys');

    if ($self->$has_rules) {
        $self->$effect(1);
        foreach my $r ($self->$all_rules) {
            if ($self->first_index_rule_names(sub {$_ eq $r}) != -1) {
                push(@rules, $r);
            }
            else {
                $self->app_log->warn(
                    "You selected a rule $r that does not exist");
                $rule_exists = 0;
                push(@rule_name_exists, $r);
            }
        }
    }
    elsif ($self->$has_bf) {
        $self->$effect(1);
        my $index = $self->first_index_rule_names(sub {$_ eq $self->$bf});
        if ($index == -1) {
            $self->app_log->warn("You "
                . $cond
                . "ed a rule "
                . $self->$bf
                . " that does not exist");
            $rule_exists = 0;
            push(@rule_name_exists, $self->$bf);
        }
        for (my $x = 0; $x <= $index; $x++) {
            push(@rules, $self->rule_names->[$x]);
        }
    }
    elsif ($self->$has_af) {
        $self->$effect(1);
        my $index = $self->first_index_rule_names(sub {$_ eq $self->$af});
        if ($index == -1) {
            $self->app_log->warn("You "
                . $cond
                . "ed a rule "
                . $self->$af
                . " that does not exist");
            $rule_exists = 0;
            push(@rule_name_exists, $self->$af);
        }
        for (my $x = $index; $x < $self->has_rule_names; $x++) {
            push(@rules, $self->rule_names->[$x]);
        }
    }
    elsif ($self->$has_btw) {
        $self->$effect(1);
        foreach my $rule ($self->$btw) {
            my (@array) = split('-', $rule);

            my $index1 =
                $self->first_index_rule_names(sub {$_ eq $array[0]});
            my $index2 =
                $self->first_index_rule_names(sub {$_ eq $array[1]});

            if ($index1 == -1 || $index2 == -1) {
                $self->app_log->warn("You "
                    . $cond
                    . "ed a set of rules "
                    . join(',', $self->$btw)
                    . " that does not exist");
                $rule_exists = 0;
                push(@rule_name_exists, $rule);
            }

            for (my $x = $index1; $x <= $index2; $x++) {
                push(@rules, $self->rule_names->[$x]);
            }
        }
    }
    elsif ($self->$has_match) {
        $self->$effect(1);
        foreach my $match_rule ($self->$all_matches) {
            my @t_rules = $self->grep_rule_names(sub {/$match_rule/});
            map {push(@rules, $_)} @t_rules;
        }
    }

    $self->$rule_keys(\@rules) if @rules;

    # return ( $rule_exists, @rule_name_exists );
}

=head3 check_select

See if the the current rule_name exists in either select_* or omit_*

=cut

sub check_select {
    my $self = shift;
    my $cond = shift || 'select';

    my $findex = 'first_index_' . $cond . '_rule_keys';
    my $index = $self->$findex(sub {$_ eq $self->rule_name});

    return 0 if $index == -1;
    return 1;
}

=head3 process_rule

This function is just a placeholder for the other functions we need to process a rule

1. Do a sanity check of the rule - it could be yaml/json friendly but not biox friendly
2. Clone the local attr
3. Check for carrying indir/outdir INPUT/OUTPUT
4. Apply the local attr - Add all the local: keys to our attr
5. Get the keys of the rule
6. Finally, process the template, or the process: key

=cut

sub process_rule {
    my $self = shift;

    my $except = $self->sanity_check_rule;
    return $except if $except;

    $self->local_attr(dclone($self->global_attr));

    $self->carry_directives;

    $self->apply_local_attr;

    $self->get_keys;
    $self->template_process;
    return 0;
}

=head3 sanity_check_rule

Check the rule to make sure it only has 1 key

=cut

#TODO make this into a type Instead

sub sanity_check_rule {
    my $self = shift;

    my $except;

    $except = $self->sanity_check_rule_one_rule_name;
    return $except if $except;

    if (!exists $self->local_rule->{ $self->rule_name }->{process}) {
        $self->local_rule->{ $self->rule_name }->{process} = '';
        $self->app_log->warn(
            'Rule does not have a process. If you have registered a namespace please ignore this error.'
        );
    }

    if (!exists $self->local_rule->{ $self->rule_name }->{local}) {
        $self->local_rule->{ $self->rule_name }->{local} = [];
    }
    else {
        $except = $self->sanity_check_rule_local_structure;
        return $except if $except;
    }

    $self->app_log->info(
        'Rule: ' . $self->rule_name . ' passes sanity check');
    return 0;
}

sub sanity_check_rule_one_rule_name {
    my $self = shift;

    my @keys = keys %{$self->local_rule};
    $self->rule_name($keys[0]);

    return if $#keys == 0;

    my $except =
        BioX::Workflow::Command::run::Rules::Exceptions::OneRuleName->new();
    $self->app_log->info('Rule: ' . $self->rule_name . ' fails sanity check');
    if (exists $self->local_rule->{process}) {
        $self->app_log->warn('\'Process\' found at same indentation as rule name. Increase the indentation for this key!');
    }
    if (exists $self->local_rule->{local}) {
        $self->app_log->warn('\'Local\' found at same indentation as rule name. Increase the indentation for this key!');
    }

    $except->warn($self->app_log);
    $self->sanity_check_fail;

    $self->inspect_obj->{errors}->{rules}->{ $self->rule_name }->{structure} =
        'OneRuleName';
    return $except;
}

sub sanity_check_rule_local_structure {
    my $self = shift;
    my $ref = $self->local_rule->{ $self->rule_name }->{local};

    return if ref($ref) eq 'ARRAY';

    my $except =
        BioX::Workflow::Command::run::Rules::Exceptions::KeyDeclaration->new();
    $self->app_log->info('Rule: ' . $self->rule_name . ' fails sanity check');
    $except->warn($self->app_log);
    $self->sanity_check_fail;
    $self->inspect_obj->{errors}->{rules}->{ $self->rule_name }->{structure} =
        'KeyDeclaration';

    return $except;
}

=head3 template_process

Do the actual processing of the rule->process

=cut

sub template_process {
    my $self = shift;
    #    my $texts = [];

    $self->process_obj->{ $self->rule_name } = {};

    ##TODO Getting rid of dummy text
    #    my $dummy_sample = $self->dummy_sample;
    #    my $dummy_texts = $self->check_iterables( $dummy_sample, [] );
    my $texts = $self->check_iterables('', []);

    $self->process_obj->{ $self->rule_name }->{text} = $texts;
    $self->process_obj->{ $self->rule_name }->{run_stats} =
        $self->local_attr->run_stats;
    #    if ( !$self->local_attr->override_process ) {
    #        foreach my $sample ( $self->all_samples ) {
    #            foreach my $text ( @{$dummy_texts} ) {
    #                my $new_text = $text;
    #                $new_text =~ s/$dummy_sample/$sample/g;
    #                push( @$texts, $new_text );
    #            }
    #        }
    #        $self->process_obj->{ $self->rule_name }->{text} = $texts;
    #        $self->process_obj->{ $self->rule_name }->{run_stats} =
    #          $self->local_attr->run_stats;
    #    }
    #    else {
    #        $self->process_obj->{ $self->rule_name }->{text} = $dummy_texts;
    #    }

    $self->process_obj->{ $self->rule_name }->{meta} =
        $self->write_rule_meta('before_meta');
}

=head3 use_iterables

This is deprecated and will be removed in the next version!

Check the global and local keys to see if we are using any iterables

  use_chroms: 1
  use_chunks: 1

This is still here, but its use is discouraged

Instead check out the Mustache Template for easier loops

=cut

sub use_iterables {
    my $self = shift;

    my $iter = '';
    my $use_iter = 0;
    my @use = ();
    map {
        if ($_ =~ m/^use_/) {push(@use, $_)}
    } @{$self->rule_keys};
    map {
        if ($_ =~ m/^use_/) {push(@use, $_)}
    } @{$self->local_rule_keys};

    my $use = pop(@use);

    return 0 if !$use;

    my $base = $use;
    $base =~ s/use_//;

    my $no = 'no_' . $base;

    return 0 if $self->local_attr->$no;

    my $elem = $base;
    $elem =~ s/s$//;
    my $all = 'all_' . $elem . '_lists';

    return [ $all, $elem ];
}

sub check_iterables {
    my $self = shift;

    if ($self->local_attr->override_process) {
        $self->render_rule_override_process;
    }
    else {
        $self->render_rule_no_override_process;
    }
}

sub render_rule_override_process {
    my $self = shift;
    my $attr = dclone($self->local_attr);
    my $text = $self->eval_process($attr);
    return [ $text ];
}

sub render_rule_no_override_process {
    my $self = shift;
    ##TODO Add some checking in here
    my @keys = ();
    my @things = ();

    ## This is all only if override_process: 0
    ## If its 1, just give to as is
    foreach my $loop (@{$self->local_attr->data_loop}) {
        push(@keys, $loop->{key});
        if (!ref($self->local_attr->{$loop->{value}})) {
            ##Try to interpolate the string
            $self->local_attr->process_directive($loop->{value}, $self->local_attr->{$loop->{value}});
        }
        push(@things, $self->local_attr->{$loop->{value}});
    }

    ##This is all possible combinations of all the nested things
    my @terms = NestedLoops(\@things,
        sub {
            my @new_things = @_;
            my $values = [];
            for (my $x = 0; $x <= $#new_things; $x++) {
                my $key = $keys[$x];
                push(@{$values}, { key => $key, value => $new_things[$x] });
            }
            return $values;
        });

    ##TODO optionally no for loop
    my $texts = $self->mce_apply_data_loop(\@terms);

    #    my @texts = map {$self->apply_data_loop($_)} @terms;
    #    return \@texts;
    $self->local_attr->stash(\%stash);
#    $self->local_attr->stash(\%stash);
    return $texts;
}

=head3

To speed things we use mce map
If, however, you do not wish to speed things,
and instead be a sucker who runs things sequentially
use this directly

=cut

sub apply_data_loop {
    my $self = shift;
    my $data_list = shift;

    return unless $data_list;
    return unless scalar @{$data_list};

    my $attr = dclone($self->local_attr);
    foreach my $data (@{$data_list}) {
        next unless $data;
        next unless exists $data->{key};
        next unless exists $data->{value};
        my $data_key = $data->{key};
        my $value = $data->{value};

        next unless defined $data_key;
        next unless defined $value;

        $self->{$data_key} = $value;
        $self->local_attr->{$data_key} = $value;
        $attr->{$data_key} = $value;
    }

    my $text = $self->eval_process($attr);
    return $text;
}

sub mce_apply_data_loop {
    my $self = shift;
    my $terms = shift;

    MCE::Map::init {chunk_size => 1, max_workers => $ENV{MAX_THREADS} || 'auto'};
    ## This is a hack having to do with this bug
    ## https://github.com/marioroy/mce-perl/issues/12
    if (scalar @{$terms}) {
        push(@{$terms}, [])
    }
    my @texts = mce_map {$self->apply_data_loop($_)} @{$terms};
    return \@texts;
}

sub walk_attr {
    my $self = shift;
    my $attr = shift;

    $self->check_indir_outdir($attr);
    $attr->walk_process_data($self->rule_keys);

    return $attr;
}

=head2

=cut

sub eval_process {
    my $self = shift;
    my $attr = shift;

    $self->check_indir_outdir($attr);
    $attr->walk_process_data($self->rule_keys);
    $self->walk_indir_outdir($attr);

    my $text = $self->eval_rule($attr);
    $text = clean_text($text);

    $self->walk_FILES($attr);
    $self->clear_files;

    $self->return_rule_as_obj($attr);

    if ($text =~ m/The following errors/) {
        $self->app_log->warn('Error for \'process\' Line #: '
            . $self->inspect_obj->{line_numbers}->{rules}
            ->{ $self->rule_name }->{process}->{line});
        $self->inspect_obj->{errors}->{rules}->{ $self->rule_name }->{process}
            ->{msg} = $text;

        $self->inspect_obj->{errors}->{rules}->{ $self->rule_name }->{process}
            ->{error_types} = $self->get_error_types('process', $text);
    }

    ##Have to add the MCE Shared stash back to the local attr
    %stash = %{dclone($attr->stash)};
    $self->local_attr->stash(\%stash);
#    $self->local_attr->stash(\%stash);

    return $text;
}

=head3 eval_rule

Check to see if there is a custom method registered.

Otherwise process the template as normal.

=cut

sub eval_rule {
    my $self = shift;
    my $attr = shift;

    my $process = $self->local_rule->{ $self->rule_name }->{process};
    my $text;

    my $eval_rule = 'eval_rule_' . $self->rule_name;
    if ($attr->can($eval_rule)) {
        try {
            $text = $attr->$eval_rule($process);
        }
        catch {
            $self->app_log->warn(
                'There was a problem evaluating rule. Error is:');
            $self->app_log->warn($_);
        };
    }
    else {
        $text = $attr->interpol_directive($process);
    }

    if ($attr->_ERROR == 1) {
        $self->app_log->warn(
            'There were 1 or more errors evaluating rule:  '
                . $self->rule_name . '. '
                . 'Please check the output file for details.'
                . "\n");
    }
    $attr->_ERROR(0);

    return $text;
}

sub get_global_keys {
    my $self = shift;
    my @global_keys = ();

    map {my ($key) = keys %{$_};
        push(@global_keys, $key)}
        @{$self->workflow_data->{global}};

    $self->global_keys(\@global_keys);
}

sub get_keys {
    my $self = shift;

    my %seen = ();
    my @local_keys = map {my ($key) = keys %{$_};
        $seen{$key} = 1;
        $key}
        @{$self->local_rule->{ $self->rule_name }->{local}};

    my @global_keys = ();
    map {my ($key) = keys %{$_};
        push(@global_keys, $key) if !$seen{$key}}
        @{$self->workflow_data->{global}};

    $self->local_rule_keys(dclone(\@local_keys));

    my @special_keys = ('indir', 'outdir', 'INPUT', 'OUTPUT');
    foreach my $key (@special_keys) {
        if (!$seen{$key}) {
            unshift(@local_keys, $key);
        }
    }

    map {push(@global_keys, $_)} @local_keys;

    $self->rule_keys(\@global_keys);
}

##TODO Write more tests
sub walk_indir_outdir {
    my $self = shift;
    my $attr = shift;

    my $text = $attr->interpol_directive($attr->outdir);
    $self->walk_indir_outdir_sample($attr, $text);
}

sub walk_indir_outdir_sample {
    my $self = shift;
    my $attr = shift;
    my $text = shift;

    foreach my $sample ($attr->all_samples) {
        my $new_text = $text;
        $new_text = path($new_text)->absolute if $attr->coerce_abs_dir;
        $new_text = path($new_text) if !$attr->coerce_abs_dir;
        $self->decide_create_outdir($attr, $new_text);
    }
}

#sub walk_indir_outdir_iters {
#    my $self      = shift;
#    my $use_iters = shift;
#    my $attr      = shift;
#    my $text      = shift;
#
#    return unless $use_iters;
#
#    my $all  = $use_iters->[0];
#    my $elem = $use_iters->[1];
#
#    my $dummy_iter = $self->dummy_iterable;
#    $attr->$elem($dummy_iter);
#
#    foreach my $chunk ( $self->local_attr->$all ) {
#        my $new_text = $text;
#        $new_text =~ s/$dummy_iter/$chunk/g;
#        $new_text = path($new_text)->absolute if $attr->coerce_abs_dir;
#        $new_text = path($new_text)           if !$attr->coerce_abs_dir;
#        $self->decide_create_outdir( $attr, $new_text );
#    }
#}

sub decide_create_outdir {
    my $self = shift;
    my $attr = shift;
    my $dir = shift;

    return unless $attr->create_outdir;
    return unless $dir;

    try {
        $dir->mkpath;
    }
    catch {
        $self->app_log->fatal("We were not able to make the directory.\n\t"
            . $attr->outdir
            . "\n\tError: $!");
    };
}

sub clean_text {
    my $text = shift;
    my @text = split("\n", $text);
    my @new_text = ();

    foreach my $t (@text) {
        $t =~ s/^\s+|\s+$//g;
        if ($t !~ /^\s*$/) {
            push(@new_text, $t);
        }
    }

    $text = join("\n", @new_text);
    return $text;
}

=head3 print_rule

Decide if we print the rule

There are 3 main decision trees

1. User specifies --select_*
2. User specified --omit_*
3. User specified --use_timestamps

select_* and omit_* take precedence over use_timestamps

=cut

sub print_rule {
    my $self = shift;
    my $print_rule = 1;

    my $select_index = $self->check_select('select');
    my $omit_index = $self->check_select('omit');

    if (!$select_index) {
        $self->app_log->info(
            'Select rules in place. Skipping rule ' . $self->rule_name);
        $print_rule = 0;
    }

    if ($omit_index) {
        $self->app_log->info(
            'Omit rules in place. Skipping rule ' . $self->rule_name);
        $print_rule = 0;
    }

    $self->app_log->info('Processing rule ' . $self->rule_name . "\n")
        if $print_rule;

    return $print_rule;
}

##This is not necessary without the use_timestamps
##But I will leave it in as a placeholder
sub print_within_rule {
    my $self = shift;

    #TODO May not need this without use_timestamps
    my $select_index = $self->check_select('select');

    return 1;
}

=head3 check_indir_outdir

If by_sample_outdir we pop the last dirname, append {$sample} to the base dir, and then add back on the popped value

There are 2 cases we do not do this

1. The indir of the first rule
2. If the user specifies indir/outdir in the local vars

=cut

sub check_indir_outdir {
    my $self = shift;
    my $attr = shift;

    # $DB::single = 2;
    return unless $attr->by_sample_outdir;
    return unless $self->has_sample;
    return if $attr->override_process;

    # If indir/outdir is specified in the local config
    # then we don't evaluate it
    my %keys = ();
    map {$keys{$_} = 1} @{$self->local_rule_keys};

    foreach my $dir (('indir', 'outdir')) {
        if (exists $keys{$dir}) {
            next;
        }

        if ($dir eq 'indir' && !$self->has_p_rule_name) {
            my $new_dir = File::Spec->catdir($attr->$dir, $attr->sample_var);
            $attr->$dir($new_dir);
            next;
        }

        my @dirs = File::Spec->splitdir($attr->$dir);
        my $last = '';
        if ($#dirs) {
            $last = pop(@dirs);
        }

        my $base_dir = File::Spec->catdir(@dirs);
        my $new_dir = File::Spec->catdir($base_dir, $attr->sample_var, $last);
        $attr->$dir($new_dir);
    }
}

=head3 carry_directives

At the beginning of each rule the previous outdir should be the new indir, and the previous OUTPUT should be the new INPUT

Stash should be carried over

Outdir should be global_attr->outdir/rule_name

=cut

sub carry_directives {
    my $self = shift;

    ##TODO File Spec This!
    $self->local_attr->outdir(
        $self->global_attr->outdir . '/' . $self->rule_name);

    return unless $self->has_p_rule_name;

    $self->local_attr->indir(dclone($self->p_local_attr->outdir));

    if ($self->p_local_attr->has_OUTPUT) {
        if (ref($self->p_local_attr->OUTPUT)) {
            $self->local_attr->INPUT(dclone($self->p_local_attr->OUTPUT));
        }
        else {
            $self->local_attr->INPUT($self->p_local_attr->OUTPUT);
        }
    }

    $self->local_attr->merge_stash(dclone($self->p_local_attr->stash));
}

sub sanity_check_fail {
    my $self = shift;

    my $rule_example = <<EOF;
global:
    - indir: data/raw
    - outdir: data/processed
    - sample_rule: (sample.*)\$
    - by_sample_outdir: 1
    - find_sample_bydir: 1
    - copy1:
        local:
            - indir: '{\$my_dir}'
            - INPUT: '{\$indir}/{\$sample}.csv'
            - HPC:
                - mem: '40GB'
                - walltime: '40GB'
        process: |
            echo 'MyDir on {\$my_dir}'
            echo 'Indir on {\$indir}'
            echo 'Outdir on {\$outdir}'
            echo 'INPUT on {\$INPUT}'
EOF
    $self->app_log->fatal('Skipping this rule.');
    $self->app_log->fatal(
        'Here is an example workflow. For more information please see biox new --help.'
    );
    $self->app_log->fatal($rule_example);
}

sub print_process_workflow {
    my $self = shift;

    $self->app_log->info('Post processing rules and printing workflow...');
    foreach my $rule ($self->all_rule_names) {

        #TODO This should be named select_rule_names
        my $index = $self->first_index_select_rule_keys(sub {$_ eq $rule});
        next if $index == -1;

        my $meta = $self->process_obj->{$rule}->{meta} || [];
        my $text = $self->process_obj->{$rule}->{text} || [];

        map {$self->fh->say($_)} @{$meta};
        $self->fh->say('');
        map {$self->fh->say($_);
            $self->fh->say('')} @{$text};

        $self->print_stats_rules($rule);

    }
}


no Moose::Role;

1;
