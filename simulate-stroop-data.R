## make a string of colours for incongruent trials
make_incongruent_trials <- function(n_trials_per_colour,
                                    stroop_colours) {
  # latin square approach for incongruent trials
  # using modular arithmatic
  addends0 <- replicate(ceiling(n_trials_per_colour / 
                                 (length(stroop_colours) - 1L)),
                       sample(seq_along(stroop_colours[-1])),
                       simplify = FALSE) |>
    unlist()
  
  addends <- addends0[seq_len(n_trials_per_colour)] |>
    rep(each = length(stroop_colours))
  
  ix <- (seq_len(n_trials_per_colour * length(stroop_colours)) - 1L +
         addends) %% 
    length(stroop_colours) + 1L
  
  stroop_colours[ix]
}

## make trials for a single subject
make_stroop_trials <- function(sid, n_err_inc,
                               n_trials_per_colour,
                               stroop_colours) {

  n_per <- n_trials_per_colour * length(stroop_colours)
  
  trials <- data.frame(
    sub_id = sid,
    trial = seq_len(2 * n_per) |> sample(),
    word = rep(stroop_colours,
               times = n_trials_per_colour * 2),
    ink_colour = c(rep(stroop_colours, n_trials_per_colour),
                   make_incongruent_trials(n_trials_per_colour,
                                           stroop_colours)),
    stringsAsFactors = FALSE)

  trials[["response"]] <- trials[["ink_colour"]]
  
  ix_inc <- sample(seq_len(n_per) + n_per, n_err_inc)

  trials[["response"]][ix_inc] <- trials[["word"]][ix_inc]
  
  trials[order(trials[["trial"]]), ]
}

## main function to make stroop data
make_stroop <- function(
   n_subj,
   n_trials_per_colour = 5, # number of trials per colour per condition
                                 #    (congruent vs. incongruent)
                                 #    so e.g., 3 = 30 trials,
                                 #    5 color words x 2 conditions x 3 reps
   stroop_colours = c("blue", "purple", "brown", "red", "green"),
   n_native = (sample(seq(.55, .65, .01), 1) * n_subj) |> round(),
   n_nonnative = n_subj - n_native,
   n_missing_lang = sample(2:5, 1),
   prob_incongruent_err = .025,
   prob_voicekey_fail = .01,
   prob_transcript_err = .04,
   congruency_eff_ms = 250,
   intercept_ms = 600,
   rt_lower_bound = 400,
   random_intercepts_sd = 100,
   random_slopes_sd = 50,
   err_sd = 200
   ) {

  stopifnot(n_subj >= 10L)

  n_trials_per_subj <- length(stroop_colours) * 2 * n_trials_per_colour

  ######################################
  ## generate subject demographics

  demographics <- data.frame(
    keep = rep(c(FALSE, TRUE), c(n_missing_lang,
                                 n_native + n_nonnative)),
    age = c(sample(18:24, n_missing_lang, TRUE),
            sample(180:244, 1), # one impossible age 
            sample(18:24, n_subj - 1L, TRUE)),
    eng_lang = c(rep(NA_character_, n_missing_lang),
                 "native",
                 c("nativ", "Native"), # incorrect variants
                 rep("native", n_native - 3L),
                 rep("nonnative", n_nonnative)),
    stringsAsFactors = FALSE)

  bad_sids <- sample(seq_len(n_subj), n_missing_lang)
  good_sids <- setdiff(seq_len(nrow(demographics)), bad_sids) |>
    sample()

  fmt_string <- paste0("S%0", log(n_subj, 10) + 1L, "d")

  demographics[["sub_id"]] <- sprintf(fmt_string,
                                      c(bad_sids, good_sids))

  #################################
  ## generate stroop task data

  ## make sure there is at least one incongruent error somewhere
  .n_tries <- 0L
  while (TRUE) {
    n_incongruent_errs <- rbinom(n_subj, n_trials_per_subj, 
                                 prob = prob_incongruent_err)
    
    if (sum(n_incongruent_errs)) break;
    .n_tries <- .n_tries + 1L
    if (.n_tries >= 1000L) {
      stop("probability of an error too low; try increasing ",
           "'prob_incongruent_err'")
    }
  }

  alltrials <- mapply(
    make_stroop_trials,
    demographics[["sub_id"]],
    c(rep(0, n_missing_lang), n_incongruent_errs),
    MoreArgs = list(n_trials_per_colour, stroop_colours),
    SIMPLIFY = FALSE) 

  trials <- do.call("rbind",
                    alltrials[order(demographics[["sub_id"]])])

  rownames(trials) <- NULL

  trials[["condition"]] <- ifelse(
    trials[["word"]] == trials[["ink_colour"]],
    "congruent", "incongruent")

  trials[["accurate"]] <- trials[["response"]] ==
    trials[["ink_colour"]]

  trials[["stimulus"]] <- paste0(toupper(trials[["word"]]), "-",
                                 trials[["ink_colour"]], ".png")

  random_intercepts <- rnorm(n_subj + n_missing_lang, 0,
                             random_intercepts_sd)
  random_slopes <- rnorm(n_subj + n_missing_lang, 0,
                         random_slopes_sd)

  random_eff <- data.frame(
    sub_id = rep((trials[["sub_id"]] |> unique()), each = 2),
    condition = rep(c("congruent", "incongruent"),
                    times = n_subj + n_missing_lang),
    rint = rep(random_intercepts, each = 2),
    rslp = rep(random_slopes, each = 2) *
      rep(c(-.5, .5), times = n_subj + n_missing_lang))
  
  dat_merged <- merge(trials, random_eff,
                      by = c("sub_id", "condition"))

  dat <- dat_merged[order(dat_merged$sub_id,
                          dat_merged$trial), ]

  ## apply linear model to generate RTs
  dat[["RT"]] <- intercept_ms +
    ifelse(dat[["condition"]] == "congruent",
           -.5 * congruency_eff_ms,
           .5 * congruency_eff_ms) +
    dat[["rint"]] + dat[["rslp"]] +
    rnorm((n_subj + n_missing_lang) *
          n_trials_per_colour * length(stroop_colours) * 2,
          sd = err_sd)

  dat[["RT"]] <- round(dat[["RT"]])

  ## to make RTs realistic we need to set a lower bound (around 400ms)
  ix <- which(dat[["RT"]] < rt_lower_bound)

  dat[["RT"]][ix] <- sample((rt_lower_bound - 10):(rt_lower_bound + 12),
                            length(ix), TRUE)

  dat

  ## 'knock out' a subset of trials where voice key failed
  bad_ids <- demographics[["sub_id"]][is.na(demographics[["eng_lang"]])]
  included <- !(dat[["sub_id"]] %in% bad_ids) & dat[["accurate"]]

  n_vkey_fails <- (prob_voicekey_fail * sum(included)) |> as.integer()
  if (!isTRUE(all.equal(prob_voicekey_fail, 0)) &&
      n_vkey_fails == 0L) {
    n_vkey_fails <- 1L ## make sure there is at least one failure
  }
  vk_ix <- sample(seq_along(included)[included], n_vkey_fails)
  dat[["vk_fail"]] <- FALSE
  dat[["vk_fail"]][vk_ix] <- TRUE
  dat[["RT_obs"]] <- dat[["RT"]]
  dat[["RT_obs"]][vk_ix] <- NA_integer_

  ## create raw data with timeline
  dat[["to_next_ms"]] <- c(sample(1700:2500, nrow(dat) - 1L, TRUE), 0L)
  subjdata <- split(dat, dat[["sub_id"]])
  dat[["tstart"]] <- lapply(subjdata, function(.x) {
    timeline <- cumsum(.x[["RT"]] + .x[["to_next_ms"]])
    inst_dur <- sample(150000:180000, 1) ## duration of instruction phase in ms
    c(0, timeline[-length(timeline)]) + inst_dur
    }) |> unlist()

  subjdata <- split(dat, dat[["sub_id"]])
  rawdata <- lapply(subjdata, function(.x) {
    stimevents <- .x[, c("trial", "tstart", "stimulus")]
    stimevents[["event"]] <- "DISPLAY_ON"
    names(stimevents) <- c("trial", "timestamp", "data", "event")
    vkevents <- .x[!.x[["vk_fail"]], c("trial", "tstart", "RT_obs")]
    vkevents[["event"]] <- "VOICE_KEY"
    vkevents[["data"]] <- ""
    vkevents[["timestamp"]] <- vkevents[["tstart"]] + vkevents[["RT_obs"]]
    allevents <- rbind(stimevents[, c("trial", "timestamp", "event", "data")],
                       vkevents[, c("trial", "timestamp", "event", "data")])
    ae2 <- allevents[order(allevents[["timestamp"]]), ]
    rownames(ae2) <- NULL
    ae2
  })

  ## add transcription errors
  n_transcript_errs <- prob_transcript_err * n_subj * n_trials_per_subj
  
  terr_ix <- sample(seq_len(nrow(dat))[included & !dat[["vk_fail"]]],
         n_transcript_errs)

  terrs <- sapply(dat[["response"]][terr_ix], function(.x) {
    ## err_vers <- sample(seq_len(3), 1)
    err_vers <- 1L
    spelling <- strsplit(.x, "")[[1]]
    if (err_vers == 1L) {
      ## exchange error
      if (length(spelling) == 3L) {
        v1 <- c(1L, 3L, 2L)
      } else {
        repeat {
          x1 <- sample(seq_along(spelling)[c(-1, -length(spelling))], 1)
          v1 <- c(1:(x1 - 1), x1 + 1L, x1)
          if ((x1 + 1L) < length(spelling)) {
            v1 <- c(v1, (x1 + 2L):length(spelling))
          }
          if (!identical(spelling[v1], spelling)) break;
        }
      }
    } else if (err_vers == 2L) {
      ## capitalization
      v1 <- seq_along(spelling)
      spelling[1] <- toupper(spelling[1])
    } else {
      ## deletion
      v1 <- -sample(seq_along(spelling)[-1], 1)
    }
    paste(spelling[v1], collapse = "")
  })

  dat[["response_obs"]] <- dat[["response"]]
  dat[["response_obs"]][terr_ix] <- terrs

  dat[["id"]] <- substr(dat[["sub_id"]], 2, length(dat[["sub_id"]])) |>
    as.integer()

  demographics[["id"]] <- substr(demographics[["sub_id"]], 2,
                                 length(demographics[["sub_id"]])) |>
    as.integer()
  
  list(demo = demographics[order(demographics$sub_id),],
       trials = dat,
       raw = rawdata)
}

save_stroop <- function(stroop, path, overwrite = FALSE) {
  if (dir.exists(path)) {
    if (!overwrite) {
      stop("output directory '", path, "' exists and overwrite = FALSE")
    } else {
      unlink(path, TRUE, TRUE)
    }
  }
  dir.create(path, FALSE)

  write.csv(stroop[["demo"]][, c("id", "age", "eng_lang")],
            file = file.path(path, "demographics.csv"),
            row.names = FALSE, na = "")
  message("wrote demographic data to '",
          file.path(path, "demographics.csv"), "'")
  

  transcript <- stroop[["trials"]][, c("id", "trial", "response_obs")]
  names(transcript)[3] <- "response"
  write.csv(transcript, file = file.path(path, "transcript.csv"),
            row.names = FALSE)
  message("wrote transcript to '",
          file.path(path, "transcript.csv"), "'")

  sid <- names(stroop[["raw"]])
  lapply(sid, function(.x) {
    fname <- file.path(path, paste0(.x, ".csv"))
    write.csv(stroop[["raw"]][[.x]],
              file = fname, row.names = FALSE)
  })
  message("wrote ", length(sid), " files with trial data to '",
          file.path(path, paste0("S",
                                 paste(rep("X", nchar(sid[1]) - 1),
                                       collapse = ""))),
          ".csv'")
  
  invisible(NULL)
}

