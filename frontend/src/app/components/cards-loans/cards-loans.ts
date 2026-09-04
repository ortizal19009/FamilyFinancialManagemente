import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService, PaginatedResult } from '../../services/api.service';
import { ConfirmService } from '../../services/confirm.service';
import { AppPaginationComponent } from '../shared/pagination/pagination';

@Component({
  selector: 'app-cards-loans',
  standalone: true,
  imports: [CommonModule, FormsModule, AppPaginationComponent],
  templateUrl: './cards-loans.html',
  styleUrl: './cards-loans.scss'
})
export class CardsLoansComponent implements OnInit {
  private apiService = inject(ApiService);
  private confirmService = inject(ConfirmService);

  cards: any[] = [];
  loans: any[] = [];
  banks: any[] = [];
  familyMembers: any[] = [];
  editingCardId: number | null = null;
  editingLoanId: number | null = null;

  cardsSearch = '';
  cardsPage = 1;
  cardsPerPage = 8;
  cardsTotal = 0;
  cardsPages = 0;
  loadingCards = false;

  loansSearch = '';
  loansPage = 1;
  loansPerPage = 8;
  loansTotal = 0;
  loansPages = 0;
  loadingLoans = false;

  private cardsSearchTimer: ReturnType<typeof setTimeout> | null = null;
  private loansSearchTimer: ReturnType<typeof setTimeout> | null = null;

  newCard = {
    bank_id: null,
    card_name: '',
    owner: '',
    last_four_digits: '',
    card_type: 'Débito',
    credit_limit: 0,
    current_debt: 0,
    available_balance: 0
  };

  newLoan = {
    bank_id: null,
    description: '',
    owner: '',
    initial_amount: 0,
    total_installments: 1,
    pending_installments: 1,
    monthly_payment: 0,
    interest_rate: 0,
    start_date: new Date().toISOString().split('T')[0]
  };

  loadingCard = false;
  loadingLoan = false;
  successMsg = '';
  errorMsg = '';

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.loadCards();
    this.loadLoans();
    this.apiService.getBanks().subscribe(data => this.banks = data);
    this.apiService.getFamilyMembers().subscribe(data => this.familyMembers = data);
  }

  private applyPageResult<T>(data: any[] | PaginatedResult<T>, setter: (items: T[]) => void): { total: number; pages: number } {
    if (Array.isArray(data)) {
      setter(data);
      return { total: data.length, pages: data.length > 0 ? 1 : 0 };
    }
    setter(data.items);
    return { total: data.total, pages: data.pages };
  }

  loadCards() {
    this.loadingCards = true;
    this.apiService.getCards({
      search: this.cardsSearch || undefined,
      page: this.cardsPage,
      per_page: this.cardsPerPage,
    }).subscribe({
      next: (data) => {
        const result = this.applyPageResult(data, items => this.cards = items);
        this.cardsTotal = result.total;
        this.cardsPages = result.pages;
        this.loadingCards = false;
      },
      error: () => {
        this.cards = [];
        this.cardsTotal = 0;
        this.cardsPages = 0;
        this.loadingCards = false;
      }
    });
  }

  loadLoans() {
    this.loadingLoans = true;
    this.apiService.getLoans({
      search: this.loansSearch || undefined,
      page: this.loansPage,
      per_page: this.loansPerPage,
    }).subscribe({
      next: (data) => {
        const result = this.applyPageResult(data, items => this.loans = items);
        this.loansTotal = result.total;
        this.loansPages = result.pages;
        this.loadingLoans = false;
      },
      error: () => {
        this.loans = [];
        this.loansTotal = 0;
        this.loansPages = 0;
        this.loadingLoans = false;
      }
    });
  }

  onSearchCardsInput() {
    if (this.cardsSearchTimer) {
      clearTimeout(this.cardsSearchTimer);
    }
    this.cardsSearchTimer = setTimeout(() => {
      this.cardsPage = 1;
      this.loadCards();
    }, 350);
  }

  onSearchLoansInput() {
    if (this.loansSearchTimer) {
      clearTimeout(this.loansSearchTimer);
    }
    this.loansSearchTimer = setTimeout(() => {
      this.loansPage = 1;
      this.loadLoans();
    }, 350);
  }

  goToCardsPage(page: number) {
    this.cardsPage = page;
    this.loadCards();
  }

  goToLoansPage(page: number) {
    this.loansPage = page;
    this.loadLoans();
  }

  onSubmitCard() {
    this.loadingCard = true;
    const request = this.editingCardId === null
      ? this.apiService.createCard(this.newCard)
      : this.apiService.updateCard(this.editingCardId, this.newCard);

    request.subscribe({
      next: () => {
        this.successMsg = this.editingCardId === null
          ? 'Tarjeta registrada correctamente'
          : 'Tarjeta actualizada correctamente';
        this.resetCardForm();
        this.loadData();
        this.loadingCard = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = this.editingCardId === null
          ? 'Error al registrar la tarjeta'
          : 'Error al actualizar la tarjeta';
        this.loadingCard = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onSubmitLoan() {
    this.loadingLoan = true;
    const request = this.editingLoanId === null
      ? this.apiService.createLoan(this.newLoan)
      : this.apiService.updateLoan(this.editingLoanId, this.newLoan);

    request.subscribe({
      next: () => {
        this.successMsg = this.editingLoanId === null
          ? 'Préstamo registrado correctamente'
          : 'Préstamo actualizado correctamente';
        this.resetLoanForm();
        this.loadData();
        this.loadingLoan = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = this.editingLoanId === null
          ? 'Error al registrar el préstamo'
          : 'Error al actualizar el préstamo';
        this.loadingLoan = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onEditCard(card: any) {
    this.editingCardId = card.id;
    this.newCard = {
      bank_id: card.bank_id ?? null,
      card_name: card.card_name ?? '',
      owner: card.owner ?? '',
      last_four_digits: card.last_four_digits ?? '',
      card_type: card.card_type ?? 'Débito',
      credit_limit: card.credit_limit ?? 0,
      current_debt: card.current_debt ?? 0,
      available_balance: card.available_balance ?? 0
    };
  }

  onDeleteCard(card: any) {
    this.confirmService.confirm({
      title: 'Eliminar tarjeta',
      message: `¿Deseas eliminar la tarjeta "${card.card_name}"?`,
      confirmLabel: 'Eliminar'
    }).subscribe(confirmed => {
      if (!confirmed) {
        return;
      }

      this.apiService.deleteCard(card.id).subscribe({
        next: () => {
          if (this.editingCardId === card.id) {
            this.resetCardForm();
          }
          this.successMsg = 'Tarjeta eliminada correctamente';
          if (this.cards.length === 1 && this.cardsPage > 1) {
            this.cardsPage -= 1;
          }
          this.loadCards();
          setTimeout(() => this.successMsg = '', 3000);
        },
        error: () => {
          this.errorMsg = 'Error al eliminar la tarjeta';
          setTimeout(() => this.errorMsg = '', 3000);
        }
      });
    });
  }

  onEditLoan(loan: any) {
    this.editingLoanId = loan.id;
    this.newLoan = {
      bank_id: loan.bank_id ?? null,
      description: loan.description ?? '',
      owner: loan.owner ?? '',
      initial_amount: loan.initial_amount ?? 0,
      total_installments: loan.total_installments ?? 1,
      pending_installments: loan.pending_installments ?? 1,
      monthly_payment: loan.monthly_payment ?? 0,
      interest_rate: loan.interest_rate ?? 0,
      start_date: loan.start_date ?? new Date().toISOString().split('T')[0]
    };
  }

  onDeleteLoan(loan: any) {
    this.confirmService.confirm({
      title: 'Eliminar préstamo',
      message: `¿Deseas eliminar el préstamo "${loan.description}"?`,
      confirmLabel: 'Eliminar'
    }).subscribe(confirmed => {
      if (!confirmed) {
        return;
      }

      this.apiService.deleteLoan(loan.id).subscribe({
        next: () => {
          if (this.editingLoanId === loan.id) {
            this.resetLoanForm();
          }
          this.successMsg = 'Préstamo eliminado correctamente';
          if (this.loans.length === 1 && this.loansPage > 1) {
            this.loansPage -= 1;
          }
          this.loadLoans();
          setTimeout(() => this.successMsg = '', 3000);
        },
        error: () => {
          this.errorMsg = 'Error al eliminar el préstamo';
          setTimeout(() => this.errorMsg = '', 3000);
        }
      });
    });
  }

  resetCardForm() {
    this.editingCardId = null;
    this.newCard = {
      bank_id: null,
      card_name: '',
      owner: '',
      last_four_digits: '',
      card_type: 'Débito',
      credit_limit: 0,
      current_debt: 0,
      available_balance: 0
    };
  }

  resetLoanForm() {
    this.editingLoanId = null;
    this.newLoan = {
      bank_id: null,
      description: '',
      owner: '',
      initial_amount: 0,
      total_installments: 1,
      pending_installments: 1,
      monthly_payment: 0,
      interest_rate: 0,
      start_date: new Date().toISOString().split('T')[0]
    };
  }
}
