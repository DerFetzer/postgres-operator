---
title: "Backup Management"
date:
draft: false
weight: 82
---

In the [previous section]({{< relref "./backups.md" >}}), we looked at a brief overview of the full disaster recovery feature set that PGO provides and explored how to [configure backups for our Postgres cluster]({{< relref "./backups.md" >}}).

Now that we have backups set up, lets look at some of the various backup management tasks we can perform. These include:

- Setting up scheduled backups
- Setting backup retention policies
- Taking one-off / ad hoc backups

## Managing Scheduled Backups

PGO sets up your Postgres clusters so that they are continuously archiving: your data is constantly being stored in your backup repository. Effectively, this is a backup!

However, in a [disaster recovery]({{< relref "./disaster-recovery.md" >}}) scenario, you likely want to get your Postgres cluster back up and running as quickly as possible (e.g. a short "[recovery time objective (RTO)](https://en.wikipedia.org/wiki/Disaster_recovery#Recovery_Time_Objective)"). What helps accomplish this is to take periodic backups. This makes it faster to restore!

[pgBackRest](https://pgbackrest.org/), the backup management tool used by PGO, provides different backup types to help both from a space management and RTO optimization perspective. These backup types include:

- **full** (`full`): A backup of your entire Postgres cluster. This is the largest of all of the backup types.
- **differential** (`diff`): A backup of all of the data since the last `full` backup.
- **incremental** (`incr`): A backup of all of the data since the last `full`, `diff`, or `incr` backup.

Selecting the appropriate backup strategy for your Postgres cluster is outside the scope of this tutorial, but let's look at how we can set up scheduled backups.

Backup schedules are stored in the `spec.archive.pgbackrest.repos.schedules` section. Each value in this section accepts a [cron-formatted](https://k8s.io/docs/concepts/workloads/controllers/cron-jobs/#cron-schedule-syntax) string that dictates the backup schedule. The available keys are `full`, `differential`, and `incremental` for full, differential, and incremental backups respectively.

Let's say that our backup policy is to take a full backup once a day at 1am and take incremental backups every four hours. We would want to add configuration to our spec that looks similar to:

```
spec:
  archive:
    pgbackrest:
      repos:
      - name: repo1
        schedules:
          full: "0 1 * * *"
          incremental: "0 */4 * * *"
```

To manage schedule backups, PGO will create several Kubernetes [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) objects that will perform backups on the specified periods. The backups will use the [configuration that you specified]({{< relref "./backups.md" >}}).

Ensuring you take regularly scheduled backups is important to maintaining Postgres cluster health. However, you don't need to keep all of your backups: this could cause you to run out of space! As such, it's also important to set a backup retention policy.

## Managing Backup Retention

PGO lets you set backup retention on full and differential backups. When a backup expires, either through your retention policy or through manual expiration, pgBackRest will clean up any backup associated with it. For example, if you have a full backup with four incremental backups associated with it, when the full backup expires, all of its incremental backups also expire.

There are two different types of backup retention you can set:

- `count`: This is based on the number of backups you want to keep. This is the default.
- `time`: This is based on the total number of days you would like to keep the a backup.

Let's look at an example where we keep full backups for 14 days. The most convenient way to do this is through the `spec.archive.pgbackrest.global` section, e.g.:

```
spec:
  archive:
    pgbackrest:
      global:
        repo1-retention-full: "14"
        repo1-retention-full-type: time
```

For a full list of available configuration options, please visit the [pgBackRest configuration](https://pgbackrest.org/configuration.html) guide.

## Taking a One-Off Backup

There are times where you may want to take a one-off backup, such as before major application changes or updates. This is not your typical declarative action -- in fact a one-off backup is imperative in its nature! -- but it is possibly to take a one-off backup of your Postgres cluster with PGO.

First, you need to configure your spec to be able to take a one-off backup, you will need to edit the `spec.archive.pgbackrest.manual` section of your custom resource. This will contain information about the type of backup you want to take and any other [pgBackRest configuration](https://pgbackrest.org/configuration.html) options.

Let's configure the custom resource to take a one-off full backup:

```
spec:
  archive:
    pgbackrest:
      manual:
        repoName: repo1
        options:
         - --type=full
```

This does not trigger the one-off backup -- you have to do that by adding the `postgres-operator.crunchydata.com/pgbackrest-backup` to your custom resource. The best way to set this annotation is with a timestamp, so you know when you initialized the backup.

For example, for our `hippo` cluster, we can run the following command to trigger the one-off backup:

```
kubectl annotate -n postgres-operator postgrescluster hippo \
  postgres-operator.crunchydata.com/pgbackrest-backup="$( date '+%F_%H:%M:%S' )"
```

PGO will detect this annotation and create a new, one-off backup Job!

If you intend to take one-off backups with similar settings in the future, you can leave those in the spec; just update the annotation to a different value the next time you are taking a backup.

## Next Steps

We've covered the fundamental tasks with managing backups. What about [restores]({{< relref "./disaster-recovery.md" >}})? Or [cloning data into new Postgres clusters]({{< relref "./disaster-recovery.md" >}})? Let's explore!