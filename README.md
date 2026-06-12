# link-shortener

Run
```
cp env-example .env
make up
```

## Benchmarking

Run `zsh -c 'for i in $(seq 1 1000); do curl -s "http://localhost:8000/rps/ztl-page-insert?payload=prefill" > /dev/null; done'` first to pre-populate the database for SELECT/UPDATE benchmarks.

**simple-text:**
```
wrk -t10 -c100 -d5s http://localhost:8000/rps/simple-text
```

**simple-json:**
```
wrk -t10 -c100 -d5s http://localhost:8000/rps/simple-json
```

**simple-ztl-page:**
```
wrk -t10 -c100 -d5s http://localhost:8000/rps/simple-ztl-page
```

**ztl-page-insert:**
```
wrk -t10 -c100 -d5s 'http://localhost:8000/rps/ztl-page-insert?payload=bench'
```

**ztl-page-select-join** (requires pre-populated data):
```
wrk -t10 -c100 -d5s 'http://localhost:8000/rps/ztl-page-select-join?limit=15'
```

**ztl-page-select-join-update:**
```
wrk -t10 -c100 -d5s 'http://localhost:8000/rps/ztl-page-select-join-update?limit=15'
```
