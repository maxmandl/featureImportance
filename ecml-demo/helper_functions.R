predict.fun = function(object, newdata) {
  #predict(object, newdata, type = "prob")[, 2]
  predict(object, newdata)
}

cartesian = function(data, features, target, keep.na = TRUE) {
  if (length(features) == 0)
    return(data)
  n = nrow(data)
  row.indices = rep(1:n, times = n)
  replace.indices = rep(1:n, each = n)
  keep.indices = row.indices != replace.indices
  data = data[row.indices, ]
  data[features] = data[replace.indices, features]
  if (keep.na) data[!keep.indices, target] = NA
  cbind("obs.id" = row.indices, "replace.id" = replace.indices, data)
}

pred = makeMeasure(id = "pred", minimize = FALSE,
  fun = function(task, model, pred, feats, extra.args) {
    #getPredictionProbabilities(pred, cl = "1")
    getPredictionResponse(pred)
  }, properties = c("classif", "regr"))


vGE = function(features, object, data, target = NULL,
  n.feat.perm = 50, measures, predict.fun = NULL, local = FALSE) {
  #assertCharacter(features)

  all.feats = setdiff(colnames(data), target)
  # shuffle all features except the ones for which we want to compute the value function
  shuffle.features = setdiff(all.feats, features)
  #shuffle.features = if (is.na(shuffle.features)) character(0) else shuffle.features
  # compute the value function
  data.perm = cartesian(data, features = shuffle.features, target, keep.na = FALSE)
  # measure performance on test data with replaced values
  geS = measurePerformance(object, data = na.omit(data.perm),
    target = target, measures = measures, predict.fun = predict.fun, local = local)

  d0 = cartesian(data, features = all.feats, target, keep.na = FALSE)
  ge0 = measurePerformance(object, data = d0,
    target = target, measures = measures, predict.fun = predict.fun, local = local)

  return(cbind(features = stri_paste(features, collapse = ","), geS - ge0))
}

vPFI = function(features, object, data, target = NULL,
  n.feat.perm = 50, measures, predict.fun = NULL, local = FALSE) {
  #assertCharacter(features)
  all.feats = setdiff(colnames(data), target)
  # shuffle all features except the ones for which we want to compute the value function
  shuffle.features = features
  shuffle.features = if (any(is.na(shuffle.features))) character(0) else shuffle.features
  # compute the value function
  data.perm = cartesian(data, features = shuffle.features, target, keep.na = FALSE)
  # measure performance on test data with replaced values
  geSc = measurePerformance(object, data = na.omit(data.perm),
    target = target, measures = measures, predict.fun = predict.fun, local = local)

  # all data
  geP = measurePerformance(object, data = data,
    target = target, measures = measures, predict.fun = predict.fun, local = local)

  return(cbind(features = stri_paste(features, collapse = ","), geSc - geP))
}

pfi = function(mod, data, target, measures, features) {
  require(featureImportance)
  # measure performance on test data
  unpermuted.perf = measurePerformance(mod, data = data, target = target,
    measures = measures, local = FALSE)

  res = setNames(lapply(features, function(feat) {
    # create all permutations
    data.perm = cartesian(data, feat, target, keep.na = FALSE)
    # measure performance on test data with replaced values
    permuted.perf = measurePerformance(mod, data = data.perm, target = target,
      measures = measures, local = FALSE)
    # measure PFI by taking differences
    pfi.diff = measureFeatureImportance(permuted.perf, unpermuted.perf)
    # measure PFI by taking ratio
    pfi.ratio = measureFeatureImportance(permuted.perf, unpermuted.perf,
      importance.fun = function(permuted, unpermuted) {permuted / unpermuted})
    list(pfi.diff = pfi.diff, pfi.ratio = pfi.ratio)
  }), features)
}

imp = function(mod, data, target, measures, features) {
  pfi = pfi(mod, data, target, measures, features)
  impGE = shapleyImportance(mod, data = data, value.function = vGE,
    target = target, measures = measures, features = features)
  impPFI = shapleyImportance(mod, data = data, value.function = vPFI,
    target = target, measures = measures, features = features)

  list(pfi = pfi, simpGE = impGE, simpPFI = impPFI)
}

ge = function(mod, data, target, measures, features) {
  require(featureImportance)
  geP = measurePerformance(mod, data = data, target = target, measures = measures)

  all.feats = setdiff(colnames(data), target)
  d0 = cartesian(data, features = all.feats, target, keep.na = FALSE)
  ge0 = measurePerformance(mod, data = d0, target = target, measures = measures)

  list(geP = geP, ge0 = ge0)
}
