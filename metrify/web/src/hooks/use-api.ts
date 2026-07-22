"use client";

import { useQuery } from "@tanstack/react-query";
import {
  fetchOverview,
  fetchDailyRevenue,
  fetchCostsByModel,
  fetchUsageByEvent,
  fetchUsageTimeline,
  fetchPendingSync,
  fetchVATTransactions,
} from "@/lib/data";

export function useOverview() {
  return useQuery({ queryKey: ["overview"], queryFn: fetchOverview, staleTime: 30000 });
}

export function useDailyRevenue() {
  return useQuery({ queryKey: ["daily-revenue"], queryFn: fetchDailyRevenue, staleTime: 30000 });
}

export function useCostsByModel() {
  return useQuery({ queryKey: ["costs-by-model"], queryFn: fetchCostsByModel, staleTime: 30000 });
}

export function useUsageByEvent() {
  return useQuery({ queryKey: ["usage-by-event"], queryFn: fetchUsageByEvent, staleTime: 30000 });
}

export function useUsageTimeline() {
  return useQuery({ queryKey: ["usage-timeline"], queryFn: fetchUsageTimeline, staleTime: 30000 });
}

export function usePendingSync() {
  return useQuery({ queryKey: ["pending-sync"], queryFn: fetchPendingSync, staleTime: 30000 });
}

export function useVATTransactions() {
  return useQuery({ queryKey: ["vat-transactions"], queryFn: fetchVATTransactions, staleTime: 30000 });
}