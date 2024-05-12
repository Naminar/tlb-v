# Simple TLB (Translation lookaside buffer) realization on verilog. 

<!-- ![](README/signals.png) -->

<p align="center">
	<img src="README/signals.png" 
		width="100%"		
		style="background-color: transparent;"
	/>
<p>

## (S)TLB
This TLB implements a 64 entries, 8-way set associative, cache with PLRU replacement policy. The second level TLB (STLB) implements 12-way set associative cache with 96 entries inside, managing by $(MRU+1)_{\%3} PLRU_4$ policy. 

<p align="center">
	<img src="https://ars.els-cdn.com/content/image/3-s2.0-B9780128200643000088-f08-25-9780128200643.jpg" 
		width="50%"		
		style="background-color: transparent;"
        display="flex"
	/>
<p>

<p align="center">
	<img src="https://i.ytimg.com/vi/S_A4fBKE1iE/maxresdefault.jpg?sqp=-oaymwEmCIAKENAF8quKqQMa8AEB-AH-CYAC0AWKAgwIABABGD8gWShyMA8=&rs=AOn4CLAZtPUjCDgXjYcuvp7TzLUIgMFy2Q" 
		width="50%"		
		style="background-color: transparent;"
	/>
<p>

- - -
## MMU
MMU (memory management unit): it behaves like memory controller. In this way, providing connections and behavior managing between PMU, TLB and STLB.
- - -
## PMU
PMU (performance management unit): provides general statistical collection capabilities generated by both caches.
- - -
## Inclusion policy 
* First level miss is followed by checking STLB.
* Hit in the second level causes insert to the TLB.
* Miss in the second level is followed by insertions to both levels. 

## PCID feature
This set contains with PCID (process context identifiers) feature for PTE is used by Intel to improve performance of paging structure.
